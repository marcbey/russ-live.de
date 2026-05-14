module StuttgartLiveSchema
  module_function

  def ensure!
    connection = ActiveRecord::Base.connection

    create_venues(connection)
    create_events(connection)
    create_event_images(connection)
    create_event_offers(connection)
    create_import_event_images(connection)
    create_app_settings(connection)
    create_action_text(connection)
    create_active_storage(connection)

    [ AppSetting, Event, EventImage, EventOffer, ImportEventImage, Venue, ActionText::RichText, ActiveStorage::Blob, ActiveStorage::Attachment ].each(&:reset_column_information)
  end

  def create_venues(connection)
    return if connection.table_exists?(:venues)

    connection.create_table :venues do |table|
      table.string :name, null: false
      table.text :address
      table.text :description
      table.string :external_url
      table.timestamps
    end
  end

  def create_events(connection)
    unless connection.table_exists?(:events)
      connection.create_table :events do |table|
        table.string :artist_name, null: false
        table.string :normalized_artist_name, null: false
        table.string :title, null: false
        table.string :slug, null: false
        table.string :status, default: "imported", null: false
        table.datetime :published_at
        table.datetime :start_at, null: false
        table.text :event_info
        table.boolean :publish_on_russ_live
        table.references :venue, null: false
        table.timestamps
      end
    end

    ensure_column(connection, :events, :promoter_id, :string)
    ensure_column(connection, :events, :promoter_name, :string)
    ensure_column(connection, :events, :highlighted, :boolean, default: false, null: false)
    ensure_column(connection, :events, :event_series_id, :integer)
    ensure_column(connection, :events, :event_series_assignment, :string, default: "auto", null: false)
    ensure_column(connection, :events, :badge_text, :string)
    ensure_column(connection, :events, :min_price, :decimal, precision: 8, scale: 2)
    ensure_column(connection, :events, :max_price, :decimal, precision: 8, scale: 2)
    ensure_column(connection, :events, :primary_source, :string)
  end

  def create_event_images(connection)
    return if connection.table_exists?(:event_images)

    connection.create_table :event_images do |table|
      table.references :event, null: false
      table.string :purpose, null: false
      table.string :alt_text
      table.text :sub_text
      table.timestamps
    end
  end

  def create_event_offers(connection)
    return if connection.table_exists?(:event_offers)

    connection.create_table :event_offers do |table|
      table.references :event, null: false
      table.jsonb :metadata, default: {}, null: false
      table.integer :priority_rank, default: 999, null: false
      table.boolean :sold_out, default: false, null: false
      table.string :source, null: false
      table.string :source_event_id, null: false
      table.string :ticket_price_text
      table.string :ticket_url
      table.timestamps
    end
  end

  def create_import_event_images(connection)
    return if connection.table_exists?(:import_event_images)

    connection.create_table :import_event_images do |table|
      table.string :aspect_hint
      table.string :image_type
      table.text :image_url
      table.string :import_class
      table.bigint :import_event_id
      table.integer :position
      table.string :role
      table.string :source
      table.timestamps
    end
  end

  def create_app_settings(connection)
    return if connection.table_exists?(:app_settings)

    connection.create_table :app_settings do |table|
      table.string :key, null: false
      table.jsonb :value, default: {}, null: false
      table.timestamps
    end

    connection.add_index :app_settings, :key, unique: true
  end

  def ensure_column(connection, table_name, column_name, type, **options)
    return if connection.column_exists?(table_name, column_name)

    connection.add_column(table_name, column_name, type, **options)
  end

  def create_action_text(connection)
    return if connection.table_exists?(:action_text_rich_texts)

    connection.create_table :action_text_rich_texts do |table|
      table.string :name, null: false
      table.text :body
      table.string :record_type, null: false
      table.bigint :record_id, null: false
      table.timestamps
    end

    connection.add_index :action_text_rich_texts, [ :record_type, :record_id, :name ], unique: true
  end

  def create_active_storage(connection)
    return if connection.table_exists?(:active_storage_blobs)

    connection.create_table :active_storage_blobs do |table|
      table.string :key, null: false
      table.string :filename, null: false
      table.string :content_type
      table.text :metadata
      table.string :service_name, null: false
      table.bigint :byte_size, null: false
      table.string :checksum
      table.datetime :created_at, null: false
    end
    connection.add_index :active_storage_blobs, :key, unique: true

    connection.create_table :active_storage_attachments do |table|
      table.string :name, null: false
      table.string :record_type, null: false
      table.bigint :record_id, null: false
      table.references :blob, null: false
      table.datetime :created_at, null: false
    end
    connection.add_index :active_storage_attachments, [ :record_type, :record_id, :name, :blob_id ], unique: true
  end
end
