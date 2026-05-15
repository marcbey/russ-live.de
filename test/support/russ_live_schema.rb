module RussLiveSchema
  module_function

  def ensure!
    connection = RussRecord.connection
    connection.schema_cache.clear!

    create_sessions(connection)
    create_login_attempts(connection)
    create_references(connection)
    create_reference_images(connection)

    [ Session, LoginAttempt, Reference, ReferenceImage ].each(&:reset_column_information)
  end

  def create_sessions(connection)
    return if table_exists?(connection, :sessions)

    connection.create_table :sessions do |table|
      table.bigint :user_id, null: false
      table.string :ip_address
      table.string :user_agent
      table.timestamps
    end

    connection.add_index :sessions, :user_id
  end

  def create_login_attempts(connection)
    return if table_exists?(connection, :login_attempts)

    connection.create_table :login_attempts do |table|
      table.bigint :user_id
      table.string :email_address
      table.string :ip_address
      table.string :user_agent
      table.string :outcome, null: false
      table.timestamps
    end
  end

  def create_references(connection)
    return if table_exists?(connection, :references)

    connection.create_table :references do |table|
      table.string :title, null: false
      table.date :starts_on, null: false
      table.string :location, null: false
      table.string :production
      table.text :description
      table.string :status, default: "draft", null: false
      table.integer :position, default: 0, null: false
      table.timestamps
    end

    connection.add_index :references, :status
  end

  def create_reference_images(connection)
    return if table_exists?(connection, :reference_images)

    connection.create_table :reference_images do |table|
      table.references :reference, null: false
      table.string :alt_text
      table.string :sub_text
      table.string :grid_variant, default: "1x1", null: false
      table.decimal :card_focus_x, precision: 5, scale: 2, default: 50, null: false
      table.decimal :card_focus_y, precision: 5, scale: 2, default: 50, null: false
      table.decimal :card_zoom, precision: 5, scale: 2, default: 100, null: false
      table.string :asset_path
      table.string :file_path
      table.string :content_type
      table.string :filename
      table.bigint :byte_size
      table.timestamps
    end

    connection.add_index :reference_images, :reference_id, unique: true
  end

  def table_exists?(connection, table_name)
    connection.select_value("SELECT to_regclass(#{connection.quote(table_name.to_s)}) IS NOT NULL")
  end
end
