module Backend
  class ReferencesController < BaseController
    FILTERS = %w[all draft published].freeze

    before_action :set_filters
    before_action :set_reference, only: %i[edit update destroy]

    def index
      prepare_index_state
    end

    def new
      @selected_reference = Reference.new(status: "draft", starts_on: Time.zone.today, position: next_position)
      @selected_reference.build_reference_image_with_defaults
      @references = filtered_references
      @active_editor_tab = editor_tab
      render :index
    end

    def edit
      redirect_to backend_references_path(
        status: status_param(@status_filter),
        query: @query_filter.presence,
        reference_id: @reference.id,
        editor_tab: editor_tab_param
      )
    end

    def create
      @selected_reference = Reference.new(create_reference_params)
      @selected_reference.position = next_position if @selected_reference.position.blank?
      prepare_reference_image(@selected_reference)

      if save_reference_with_upload(@selected_reference)
        redirect_to backend_references_path(reference_id: @selected_reference.id, status: @selected_reference.status, editor_tab: editor_tab_param), notice: "Referenz wurde erstellt."
      else
        flash.now[:alert] = "Referenz konnte nicht gespeichert werden."
        render_invalid_state(:unprocessable_entity)
      end
    end

    def update
      @selected_reference = @reference
      @selected_reference.assign_attributes(reference_params) if params[:reference].present?
      prepare_reference_image(@selected_reference)

      if save_reference_with_upload(@selected_reference)
        redirect_to backend_references_path(reference_id: @selected_reference.id, status: status_param(@status_filter), query: @query_filter.presence, editor_tab: editor_tab_param), notice: "Referenz wurde gespeichert."
      else
        flash.now[:alert] = "Referenz konnte nicht gespeichert werden."
        render_invalid_state(:unprocessable_entity)
      end
    end

    def destroy
      @reference.destroy!
      redirect_to backend_references_path(status: status_param(@status_filter), query: @query_filter.presence), notice: "Referenz wurde gelöscht."
    end

    private
      def set_filters
        @status_filter = params[:status].to_s.presence_in(FILTERS) || "all"
        @query_filter = params[:query].to_s.strip.presence
      end

      def set_reference
        @reference = Reference.with_image.find(params[:id])
      end

      def prepare_index_state
        @references = filtered_references
        @selected_reference = selected_reference_from(@references)
        @active_editor_tab = editor_tab
      end

      def filtered_references
        scope = Reference.with_image.ordered.matching(@query_filter)
        scope = scope.where(status: @status_filter) unless @status_filter == "all"
        scope.to_a
      end

      def selected_reference_from(references)
        selected_id = params[:reference_id].to_i
        return references.find { |reference| reference.id == selected_id } if selected_id.positive?

        references.first
      end

      def reference_params
        params.require(:reference).permit(:title, :starts_on, :location, :production, :description, :status, :position)
      end

      def create_reference_params
        params.fetch(:reference, ActionController::Parameters.new)
          .permit(:title, :starts_on, :location, :production, :description, :status, :position)
          .reverse_merge(
            title: fallback_reference_title,
            starts_on: Time.zone.today,
            location: "Noch nicht angegeben",
            status: "draft"
          )
      end

      def reference_image_params
        params.fetch(:reference_image, ActionController::Parameters.new).permit(
          :alt_text,
          :sub_text,
          :grid_variant,
          :card_focus_x,
          :card_focus_y,
          :card_zoom,
          :remove_image
        )
      end

      def uploaded_image
        params.dig(:reference_image, :file)
      end

      def fallback_reference_title
        reference_image_params[:alt_text].presence ||
          uploaded_image&.original_filename.to_s.sub(/\.[^.]+\z/, "").presence ||
          "Neue Referenz"
      end

      def prepare_reference_image(reference)
        image = reference.reference_image || reference.build_reference_image
        image.assign_attributes(reference_image_params.except(:remove_image))
        image.alt_text = reference.title if image.alt_text.blank?

        return unless remove_image_requested? && uploaded_image.blank?

        image.purge_file!
        image.assign_attributes(asset_path: nil, file_path: nil, filename: nil, content_type: nil, byte_size: nil)
      end

      def save_reference_with_upload(reference)
        Reference.transaction do
          reference.save!
          reference.reference_image&.save!
          reference.reference_image&.write_uploaded_file!(uploaded_image) if uploaded_image.present?
        end

        true
      rescue ActiveRecord::RecordInvalid
        false
      end

      def remove_image_requested?
        ActiveModel::Type::Boolean.new.cast(reference_image_params[:remove_image])
      end

      def render_invalid_state(status)
        @references = filtered_references
        @active_editor_tab = editor_tab
        render :index, status: status
      end

      def next_position
        Reference.maximum(:position).to_i + 1
      end

      def editor_tab
        params[:editor_tab].to_s.presence_in(%w[reference image]) || "reference"
      end

      def editor_tab_param
        editor_tab == "reference" ? nil : editor_tab
      end

      def status_param(filter)
        filter == "all" ? nil : filter
      end
  end
end
