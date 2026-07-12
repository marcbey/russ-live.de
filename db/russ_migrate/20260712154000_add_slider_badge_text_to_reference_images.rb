class AddSliderBadgeTextToReferenceImages < ActiveRecord::Migration[8.1]
  def change
    add_column :reference_images, :slider_badge_text, :string
  end
end
