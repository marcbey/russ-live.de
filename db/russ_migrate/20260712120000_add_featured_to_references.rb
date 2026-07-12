class AddFeaturedToReferences < ActiveRecord::Migration[8.1]
  def change
    add_column :references, :featured, :boolean, default: false, null: false
    add_index :references, :featured
  end
end
