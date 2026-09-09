class AddEnglishFieldsToJobs < ActiveRecord::Migration[8.1]
  def change
    add_column :jobs, :title_en, :string
    add_column :jobs, :badge_en, :string
    add_column :jobs, :intro_en, :text
    add_column :jobs, :highlight_text_en, :text
    add_column :jobs, :responsibilities_en, :text, array: true, default: [], null: false
    add_column :jobs, :requirements_en, :text, array: true, default: [], null: false
    add_column :jobs, :meta_title_en, :string
    add_column :jobs, :meta_description_en, :text
  end
end
