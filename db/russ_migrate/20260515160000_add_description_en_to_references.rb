class AddDescriptionEnToReferences < ActiveRecord::Migration[8.1]
  def change
    add_column :references, :description_en, :text
  end
end
