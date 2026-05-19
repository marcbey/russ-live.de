class AddSliderFieldsToReferenceImages < ActiveRecord::Migration[8.1]
  def change
    change_table :reference_images, bulk: true do |t|
      t.string :slider_alt_text
      t.string :slider_sub_text
      t.string :slider_asset_path
      t.string :slider_file_path
      t.string :slider_content_type
      t.string :slider_filename
      t.bigint :slider_byte_size
    end
  end
end
