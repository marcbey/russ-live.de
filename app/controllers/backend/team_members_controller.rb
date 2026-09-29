module Backend
  class TeamMembersController < BaseController
    before_action :set_filters
    before_action :set_team_member, only: %i[edit update destroy]

    def index
      prepare_index_state
    end

    def new
      @selected_team_member = TeamMember.new(position: next_position)
      @selected_team_member.build_team_member_image_with_defaults
      @team_members = filtered_team_members
      @active_editor_tab = editor_tab
      render :index
    end

    def edit
      redirect_to backend_team_members_path(query: @query_filter.presence, team_member_id: @team_member.id, editor_tab: editor_tab_param)
    end

    def create
      @selected_team_member = TeamMember.new(name: fallback_team_member_name)
      assign_team_member_attributes(@selected_team_member)
      @selected_team_member.position = next_position
      prepare_team_member_image(@selected_team_member)

      if save_team_member_with_upload(@selected_team_member)
        redirect_to backend_team_members_path(team_member_id: @selected_team_member.id, editor_tab: editor_tab_param), notice: "Teammitglied wurde erstellt."
      else
        flash.now[:alert] = "Teammitglied konnte nicht gespeichert werden."
        render_invalid_state(:unprocessable_entity)
      end
    end

    def update
      @selected_team_member = @team_member
      assign_team_member_attributes(@selected_team_member)
      prepare_team_member_image(@selected_team_member)

      if save_team_member_with_upload(@selected_team_member)
        redirect_to backend_team_members_path(team_member_id: @selected_team_member.id, query: @query_filter.presence, editor_tab: editor_tab_param), notice: "Teammitglied wurde gespeichert."
      else
        flash.now[:alert] = "Teammitglied konnte nicht gespeichert werden."
        render_invalid_state(:unprocessable_entity)
      end
    end

    def destroy
      @team_member.destroy!
      redirect_to backend_team_members_path(query: @query_filter.presence), notice: "Teammitglied wurde gelöscht."
    end

    def reorder
      ids = params.fetch(:team_member_ids, []).map(&:to_i)
      members = TeamMember.where(id: ids).index_by(&:id)
      return head :unprocessable_entity unless members.size == ids.uniq.size

      TeamMember.transaction do
        ids.each_with_index { |id, index| members.fetch(id).update!(position: index + 1) }
      end
      head :no_content
    end

    private
      def set_filters
        @query_filter = params[:query].to_s.strip.presence
      end

      def set_team_member
        @team_member = TeamMember.with_image.find(params[:id])
      end

      def prepare_index_state
        @team_members = filtered_team_members
        @selected_team_member = selected_team_member_from(@team_members)
        @active_editor_tab = editor_tab
      end

      def filtered_team_members
        TeamMember.with_image.ordered.matching(@query_filter).to_a
      end

      def selected_team_member_from(members)
        selected_id = params[:team_member_id].to_i
        return members.find { |member| member.id == selected_id } if selected_id.positive?

        members.first
      end

      def assign_team_member_attributes(member)
        attributes = params[:team_member]
        return if attributes.blank?

        member.name = attributes[:name] if attributes.key?(:name)
        member.role = attributes[:role] if attributes.key?(:role)
        member.role_en = attributes[:role_en] if attributes.key?(:role_en)
      end

      def image_params
        params.fetch(:team_member_image, ActionController::Parameters.new).permit(:remove_image)
      end

      def uploaded_image
        params.dig(:team_member_image, :file)
      end

      def fallback_team_member_name
        uploaded_image&.original_filename.to_s.sub(/\.[^.]+\z/, "").presence || "Neues Teammitglied"
      end

      def prepare_team_member_image(member)
        image = member.team_member_image || member.build_team_member_image
        image.assign_attributes(image_params.except(:remove_image))
        image.alt_text = member.name
        image.sub_text = nil
        return unless ActiveModel::Type::Boolean.new.cast(image_params[:remove_image]) && uploaded_image.blank?

        image.purge_file!
        image.assign_attributes(asset_path: nil, file_path: nil, filename: nil, content_type: nil, byte_size: nil)
      end

      def save_team_member_with_upload(member)
        TeamMember.transaction do
          member.save!
          member.team_member_image&.save!
          member.team_member_image&.write_uploaded_file!(uploaded_image) if uploaded_image.present?
        end
        true
      rescue ActiveRecord::RecordInvalid
        false
      end

      def render_invalid_state(status)
        @team_members = filtered_team_members
        @active_editor_tab = editor_tab
        render :index, status: status
      end

      def next_position = TeamMember.maximum(:position).to_i + 1
      def editor_tab = params[:editor_tab].to_s.presence_in(%w[team_member image]) || "team_member"
      def editor_tab_param = editor_tab == "team_member" ? nil : editor_tab
  end
end
