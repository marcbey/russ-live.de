class AddTagsToReferences < ActiveRecord::Migration[8.1]
  def change
    add_column :references, :tags, :string, array: true, default: [], null: false
    add_index :references, :tags, using: :gin
  end
end
