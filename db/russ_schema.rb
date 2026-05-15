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

ActiveRecord::Schema[8.1].define(version: 2026_05_14_143000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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
    t.string "sub_text"
    t.datetime "updated_at", null: false
    t.index ["reference_id"], name: "index_reference_images_on_reference_id", unique: true
  end

  create_table "references", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "location", null: false
    t.integer "position", default: 0, null: false
    t.string "production"
    t.date "starts_on", null: false
    t.string "status", default: "draft", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["position", "starts_on"], name: "index_references_on_position_and_starts_on"
    t.index ["status"], name: "index_references_on_status"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  add_foreign_key "reference_images", "references"
end
