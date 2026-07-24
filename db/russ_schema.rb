# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_24_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "contact_images", force: :cascade do |t|
    t.string "alt_text"
    t.string "asset_path"
    t.bigint "byte_size"
    t.bigint "contact_id", null: false
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "file_path"
    t.string "filename"
    t.string "sub_text"
    t.datetime "updated_at", null: false
    t.index ["contact_id"], name: "index_contact_images_on_contact_id", unique: true
  end

  create_table "contacts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "phone_number", null: false
    t.integer "position", default: 0, null: false
    t.string "role"
    t.datetime "updated_at", null: false
    t.index ["position"], name: "index_contacts_on_position"
  end

  create_table "job_images", force: :cascade do |t|
    t.string "alt_text"
    t.string "asset_path"
    t.bigint "byte_size"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "file_path"
    t.string "filename"
    t.bigint "job_id", null: false
    t.string "sub_text"
    t.datetime "updated_at", null: false
    t.index ["job_id"], name: "index_job_images_on_job_id", unique: true
  end

  create_table "jobs", force: :cascade do |t|
    t.string "badge"
    t.string "categories", default: [], null: false, array: true
    t.bigint "contact_id"
    t.datetime "created_at", null: false
    t.string "employment"
    t.string "highlight_label"
    t.text "highlight_text"
    t.string "highlight_title"
    t.text "intro"
    t.string "join_recruiting_url"
    t.string "location", null: false
    t.text "meta_description"
    t.string "meta_title"
    t.integer "position", default: 0, null: false
    t.text "requirements", default: [], null: false, array: true
    t.text "responsibilities", default: [], null: false, array: true
    t.string "slug", null: false
    t.string "status", default: "draft", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["categories"], name: "index_jobs_on_categories", using: :gin
    t.index ["contact_id"], name: "index_jobs_on_contact_id"
    t.index ["position"], name: "index_jobs_on_position"
    t.index ["slug"], name: "index_jobs_on_slug", unique: true
    t.index ["status"], name: "index_jobs_on_status"
  end

  create_table "login_attempts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address"
    t.string "ip_address"
    t.string "outcome", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id"
    t.index ["created_at"], name: "index_login_attempts_on_created_at"
    t.index ["email_address", "created_at"], name: "index_login_attempts_on_email_address_and_created_at"
    t.index ["outcome", "created_at"], name: "index_login_attempts_on_outcome_and_created_at"
    t.index ["user_id"], name: "index_login_attempts_on_user_id"
  end

  create_table "reference_images", force: :cascade do |t|
    t.string "alt_text"
    t.string "asset_path"
    t.bigint "byte_size"
    t.decimal "card_focus_x", precision: 5, scale: 2, default: "50.0", null: false
    t.decimal "card_focus_y", precision: 5, scale: 2, default: "50.0", null: false
    t.decimal "card_zoom", precision: 5, scale: 2, default: "100.0", null: false
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "file_path"
    t.string "filename"
    t.string "grid_variant", default: "1x1", null: false
    t.bigint "reference_id", null: false
    t.string "slider_alt_text"
    t.string "slider_asset_path"
    t.string "slider_badge_text"
    t.bigint "slider_byte_size"
    t.string "slider_content_type"
    t.string "slider_file_path"
    t.string "slider_filename"
    t.string "slider_mobile_asset_path"
    t.bigint "slider_mobile_byte_size"
    t.string "slider_mobile_content_type"
    t.string "slider_mobile_file_path"
    t.string "slider_mobile_filename"
    t.string "slider_sub_text"
    t.string "sub_text"
    t.datetime "updated_at", null: false
    t.index ["reference_id"], name: "index_reference_images_on_reference_id", unique: true
  end

  create_table "references", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.text "description_en"
    t.string "display_date"
    t.boolean "featured", default: false, null: false
    t.string "location", null: false
    t.integer "position", default: 0, null: false
    t.string "production"
    t.date "starts_on", null: false
    t.string "status", default: "draft", null: false
    t.string "tags", default: [], null: false, array: true
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["featured"], name: "index_references_on_featured"
    t.index ["position", "starts_on"], name: "index_references_on_position_and_starts_on"
    t.index ["status"], name: "index_references_on_status"
    t.index ["tags"], name: "index_references_on_tags", using: :gin
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  add_foreign_key "contact_images", "contacts"
  add_foreign_key "job_images", "jobs"
  add_foreign_key "jobs", "contacts"
  add_foreign_key "reference_images", "references"
end
