module Backend
  class JobsController < BaseController
    FILTERS = %w[all draft published].freeze

    before_action :set_filters
    before_action :set_job, only: %i[edit update destroy]

    def index
      prepare_index_state
    end

    def new
      @selected_job = Job.new(status: "draft", position: next_position, contact: Contact.ordered.first)
      @selected_job.build_job_image_with_defaults
      @jobs = filtered_jobs
      @contacts = contacts_for_select
      @active_editor_tab = editor_tab
      render :index
    end

    def edit
      redirect_to backend_jobs_path(status: status_param(@status_filter), query: @query_filter.presence, job_id: @job.id, editor_tab: editor_tab_param)
    end

    def create
      @selected_job = Job.new(create_job_params)
      @selected_job.position = next_position if @selected_job.position.blank?
      prepare_job_image(@selected_job)

      if save_job_with_upload(@selected_job)
        redirect_to backend_jobs_path(job_id: @selected_job.id, status: @selected_job.status, editor_tab: editor_tab_param), notice: "Job wurde erstellt."
      else
        flash.now[:alert] = "Job konnte nicht gespeichert werden."
        render_invalid_state(:unprocessable_entity)
      end
    end

    def update
      @selected_job = @job
      @selected_job.assign_attributes(job_params) if params[:job].present?
      prepare_job_image(@selected_job)

      if save_job_with_upload(@selected_job)
        redirect_to backend_jobs_path(job_id: @selected_job.id, status: status_param(@status_filter), query: @query_filter.presence, editor_tab: editor_tab_param), notice: "Job wurde gespeichert."
      else
        flash.now[:alert] = "Job konnte nicht gespeichert werden."
        render_invalid_state(:unprocessable_entity)
      end
    end

    def destroy
      @job.destroy!
      redirect_to backend_jobs_path(status: status_param(@status_filter), query: @query_filter.presence), notice: "Job wurde gelöscht."
    end

    private
      def set_filters
        @status_filter = params[:status].to_s.presence_in(FILTERS) || "all"
        @query_filter = params[:query].to_s.strip.presence
      end

      def set_job
        @job = Job.with_contact_and_image.find(params[:id])
      end

      def prepare_index_state
        @jobs = filtered_jobs
        @selected_job = selected_job_from(@jobs)
        @contacts = contacts_for_select
        @active_editor_tab = editor_tab
      end

      def filtered_jobs
        scope = Job.with_contact_and_image.ordered.matching(@query_filter)
        scope = scope.where(status: @status_filter) unless @status_filter == "all"
        scope.to_a
      end

      def selected_job_from(jobs)
        selected_id = params[:job_id].to_i
        return jobs.find { |job| job.id == selected_id } if selected_id.positive?

        jobs.first
      end

      def contacts_for_select
        Contact.ordered.to_a
      end

      def job_params
        params.require(:job).permit(
          :contact_id,
          :slug,
          :title,
          :badge,
          :employment,
          :location,
          :intro,
          :highlight_label,
          :highlight_title,
          :highlight_text,
          :category_list,
          :responsibilities_text,
          :requirements_text,
          :join_recruiting_url,
          :meta_title,
          :meta_description,
          :status,
          :position
        )
      end

      def create_job_params
        params.fetch(:job, ActionController::Parameters.new)
          .permit(:contact_id, :slug, :title, :badge, :employment, :location, :intro, :highlight_label, :highlight_title, :highlight_text, :category_list, :responsibilities_text, :requirements_text, :join_recruiting_url, :meta_title, :meta_description, :status, :position)
          .reverse_merge(title: fallback_job_title, location: "Stuttgart", status: "draft")
      end

      def job_image_params
        params.fetch(:job_image, ActionController::Parameters.new).permit(:alt_text, :sub_text, :remove_image)
      end

      def uploaded_image
        params.dig(:job_image, :file)
      end

      def fallback_job_title
        job_image_params[:alt_text].presence ||
          uploaded_image&.original_filename.to_s.sub(/\.[^.]+\z/, "").presence ||
          "Neuer Job"
      end

      def prepare_job_image(job)
        image = job.job_image || job.build_job_image
        image.assign_attributes(job_image_params.except(:remove_image))
        image.alt_text = job.title if image.alt_text.blank?

        return unless remove_image_requested? && uploaded_image.blank?

        image.purge_file!
        image.assign_attributes(asset_path: nil, file_path: nil, filename: nil, content_type: nil, byte_size: nil)
      end

      def save_job_with_upload(job)
        Job.transaction do
          job.save!
          job.job_image&.save!
          job.job_image&.write_uploaded_file!(uploaded_image) if uploaded_image.present?
        end

        true
      rescue ActiveRecord::RecordInvalid
        false
      end

      def remove_image_requested?
        ActiveModel::Type::Boolean.new.cast(job_image_params[:remove_image])
      end

      def render_invalid_state(status)
        @jobs = filtered_jobs
        @contacts = contacts_for_select
        @active_editor_tab = editor_tab
        render :index, status: status
      end

      def next_position
        Job.maximum(:position).to_i + 1
      end

      def editor_tab
        params[:editor_tab].to_s.presence_in(%w[job image]) || "job"
      end

      def editor_tab_param
        editor_tab == "job" ? nil : editor_tab
      end

      def status_param(filter)
        filter == "all" ? nil : filter
      end
  end
end
