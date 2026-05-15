require "test_helper"

class ContactTest < ActiveSupport::TestCase
  setup do
    RussLiveSchema.ensure!
    JobImage.delete_all
    Job.delete_all
    ContactImage.delete_all
    Contact.delete_all
  end

  test "validates required fields" do
    contact = Contact.new(email: "invalid")

    assert_not contact.valid?
    assert_includes contact.errors[:name], "can't be blank"
    assert_includes contact.errors[:phone_number], "can't be blank"
    assert_includes contact.errors[:email], "is invalid"
  end

  test "normalizes phone number for tel link" do
    contact = Contact.create!(
      name: "Sebastian Kränzlein",
      phone_number: "+49.711.16 353 42",
      email: "SEBASTIAN@example.com"
    )

    assert_equal "+497111635342", contact.tel_href
    assert_equal "sebastian@example.com", contact.email
  end

  test "prevents destroying contacts referenced by jobs" do
    contact = create_contact!
    Job.create!(contact: contact, title: "Stagehands", slug: "stagehands", location: "Stuttgart", status: "published")

    assert_not contact.destroy
    assert_includes contact.errors[:base], "Cannot delete record because dependent jobs exist"
  end

  private
    def create_contact!
      Contact.create!(name: "Sebastian Kränzlein", phone_number: "+49.711.16 353 42", email: "personal@example.com")
    end
end
