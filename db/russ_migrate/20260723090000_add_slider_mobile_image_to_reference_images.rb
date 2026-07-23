class AddSliderMobileImageToReferenceImages < ActiveRecord::Migration[8.1]
  def change
    change_table :reference_images, bulk: true do |t|
      t.string :slider_mobile_asset_path
      t.string :slider_mobile_file_path
      t.string :slider_mobile_content_type
      t.string :slider_mobile_filename
      t.bigint :slider_mobile_byte_size
    end
  end
end
