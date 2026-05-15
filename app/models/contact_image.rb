class ContactImage < RussRecord
  include RussImageUpload

  belongs_to :contact

  def storage_directory
    "contact_images"
  end

  private
    def image_owner_name
      contact.name
    end
end
