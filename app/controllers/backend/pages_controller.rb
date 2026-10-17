module Backend
  class PagesController < BaseController
    before_action :set_page, only: %i[update preview]

    def index
      prepare_index_state
    end

    def update
      @selected_page = @page
      @selected_page.assign_attributes(page_params)
      @selected_page.content = @selected_page.content.merge(page_content_params)

      if publish_page_requested?
        publish_page
      else
        save_draft_page
      end
    end

    def preview
      @editable_page = @page
      @page_key = @page.key.to_sym
      @public_header_jobs = Job.published.ordered.to_a
      @page_meta = ::PagesController::PAGE_META.fetch(@page_key).merge(
        title: @page.meta_title.presence || @page.title,
        description: @page.meta_description
      )

      render "pages/#{@page.key}"
    end

    private
      def set_page
        @page = EditablePage.find(params[:id])
      end

      def prepare_index_state
        @editable_pages = EditablePage.editor_pages
        @selected_page = selected_page_from(@editable_pages)
      end

      def selected_page_from(pages)
        selected_id = params[:page_id].to_i
        return pages.find { |page| page.id == selected_id } if selected_id.positive?

        pages.first
      end

      def page_params
        params.require(:editable_page).permit(:title, :meta_title, :meta_description)
      end

      def page_content_params
        params.require(:editable_page)
          .fetch(:content, ActionController::Parameters.new)
          .permit(*@selected_page.content_field_names)
          .to_h
      end

      def publish_page_requested?
        ActiveModel::Type::Boolean.new.cast(params[:publish_page])
      end

      def publish_page
        @selected_page.publish!
        redirect_to backend_pages_path(page_id: @selected_page.id), notice: "Seite wurde veröffentlicht."
      rescue ActiveRecord::RecordInvalid
        flash.now[:alert] = "Seite konnte nicht veröffentlicht werden."
        render_invalid_state(:unprocessable_entity)
      end

      def save_draft_page
        @selected_page.draft!

        if @selected_page.save
          redirect_to backend_pages_path(page_id: @selected_page.id), notice: "Seite wurde gespeichert."
        else
          flash.now[:alert] = "Seite konnte nicht gespeichert werden."
          render_invalid_state(:unprocessable_entity)
        end
      end

      def render_invalid_state(status)
        @editable_pages = EditablePage.editor_pages
        render :index, status: status
      end
  end
end
