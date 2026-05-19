class AddDisplayDateToReferences < ActiveRecord::Migration[8.1]
  def change
    add_column :references, :display_date, :string
  end
end
