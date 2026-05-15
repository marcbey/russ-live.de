module Backend
  class ContactsController < BaseController
    before_action :set_filters
    before_action :set_contact, only: %i[edit update destroy]

    def index
      prepare_index_state
    end

    def new
      @selected_contact = Contact.new(position: next_position)
      @selected_contact.build_contact_image_with_defaults
      @contacts = filtered_contacts
      @active_editor_tab = editor_tab
      render :index
    end

    def edit
      redirect_to backend_contacts_path(query: @query_filter.presence, contact_id: @contact.id, editor_tab: editor_tab_param)
    end

    def create
      @selected_contact = Contact.new(create_contact_params)
      @selected_contact.position = next_position if @selected_contact.position.blank?
      prepare_contact_image(@selected_contact)

      if save_contact_with_upload(@selected_contact)
        redirect_to backend_contacts_path(contact_id: @selected_contact.id, editor_tab: editor_tab_param), notice: "Ansprechpartner wurde erstellt."
      else
        flash.now[:alert] = "Ansprechpartner konnte nicht gespeichert werden."
        render_invalid_state(:unprocessable_entity)
      end
    end

    def update
      @selected_contact = @contact
      @selected_contact.assign_attributes(contact_params) if params[:contact].present?
      prepare_contact_image(@selected_contact)

      if save_contact_with_upload(@selected_contact)
        redirect_to backend_contacts_path(contact_id: @selected_contact.id, query: @query_filter.presence, editor_tab: editor_tab_param), notice: "Ansprechpartner wurde gespeichert."
      else
        flash.now[:alert] = "Ansprechpartner konnte nicht gespeichert werden."
        render_invalid_state(:unprocessable_entity)
      end
    end

    def destroy
      if @contact.destroy
        redirect_to backend_contacts_path(query: @query_filter.presence), notice: "Ansprechpartner wurde gelöscht."
      else
        @selected_contact = @contact
        flash.now[:alert] = "Ansprechpartner kann nicht gelöscht werden, solange Jobs ihn verwenden."
        render_invalid_state(:unprocessable_entity)
      end
    end

    private
      def set_filters
        @query_filter = params[:query].to_s.strip.presence
      end

      def set_contact
        @contact = Contact.with_image.find(params[:id])
      end

      def prepare_index_state
        @contacts = filtered_contacts
        @selected_contact = selected_contact_from(@contacts)
        @active_editor_tab = editor_tab
      end

      def filtered_contacts
        Contact.with_image.ordered.matching(@query_filter).to_a
      end

      def selected_contact_from(contacts)
        selected_id = params[:contact_id].to_i
        return contacts.find { |contact| contact.id == selected_id } if selected_id.positive?

        contacts.first
      end

      def contact_params
        contact = params.require(:contact)

        {
          name: contact[:name],
          role: contact[:role],
          phone_number: contact[:phone_number],
          email: contact[:email],
          position: contact[:position]
        }
      end

      def create_contact_params
        contact_params.reverse_merge(name: fallback_contact_name, phone_number: "+49", email: "personal@russ-live.de")
      rescue ActionController::ParameterMissing
        {
          name: fallback_contact_name,
          phone_number: "+49",
          email: "personal@russ-live.de"
        }
      end

      def contact_image_params
        params.fetch(:contact_image, ActionController::Parameters.new).permit(:remove_image)
      end

      def uploaded_image
        params.dig(:contact_image, :file)
      end

      def fallback_contact_name
        uploaded_image&.original_filename.to_s.sub(/\.[^.]+\z/, "").presence ||
          "Neuer Ansprechpartner"
      end

      def prepare_contact_image(contact)
        image = contact.contact_image || contact.build_contact_image
        image.assign_attributes(contact_image_params.except(:remove_image))
        image.alt_text = contact.name
        image.sub_text = nil

        return unless remove_image_requested? && uploaded_image.blank?

        image.purge_file!
        image.assign_attributes(asset_path: nil, file_path: nil, filename: nil, content_type: nil, byte_size: nil)
      end

      def save_contact_with_upload(contact)
        Contact.transaction do
          contact.save!
          contact.contact_image&.save!
          contact.contact_image&.write_uploaded_file!(uploaded_image) if uploaded_image.present?
        end

        true
      rescue ActiveRecord::RecordInvalid
        false
      end

      def remove_image_requested?
        ActiveModel::Type::Boolean.new.cast(contact_image_params[:remove_image])
      end

      def render_invalid_state(status)
        @contacts = filtered_contacts
        @active_editor_tab = editor_tab
        render :index, status: status
      end

      def next_position
        Contact.maximum(:position).to_i + 1
      end

      def editor_tab
        params[:editor_tab].to_s.presence_in(%w[contact image]) || "contact"
      end

      def editor_tab_param
        editor_tab == "contact" ? nil : editor_tab
      end
  end
end
