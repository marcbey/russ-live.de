class CreateEditablePages < ActiveRecord::Migration[8.1]
  def change
    create_table :editable_pages do |t|
      t.string :key, null: false
      t.string :locale, null: false
      t.string :title, null: false
      t.jsonb :content, default: {}, null: false
      t.string :meta_title
      t.text :meta_description
      t.string :status, default: "published", null: false
      t.string :published_title
      t.jsonb :published_content, default: {}, null: false
      t.string :published_meta_title
      t.text :published_meta_description
      t.datetime :published_at

      t.timestamps
    end

    add_index :editable_pages, [ :key, :locale ], unique: true
    add_index :editable_pages, :status
  end
end
