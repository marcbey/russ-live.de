module RussLiveSchema
  module_function

  def ensure!
    connection = RussRecord.connection
    connection.schema_cache.clear!

    create_sessions(connection)
    create_login_attempts(connection)
    create_references(connection)
    add_reference_description_en(connection)
    add_reference_display_date(connection)
    add_reference_tags(connection)
    create_reference_images(connection)
    add_reference_slider_image_fields(connection)
    create_contacts(connection)
    create_contact_images(connection)
    create_jobs(connection)
    create_job_images(connection)

    [ Session, LoginAttempt, Reference, ReferenceImage, Contact, ContactImage, Job, JobImage ].each(&:reset_column_information)
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
      table.string :display_date
      table.string :tags, array: true, default: [], null: false
      table.text :description
      table.text :description_en
      table.string :status, default: "draft", null: false
      table.integer :position, default: 0, null: false
      table.timestamps
    end

    connection.add_index :references, :status
    connection.add_index :references, :tags, using: :gin
  end

  def add_reference_description_en(connection)
    return unless table_exists?(connection, :references)
    return if connection.column_exists?(:references, :description_en)

    connection.add_column :references, :description_en, :text
  end

  def add_reference_display_date(connection)
    return unless table_exists?(connection, :references)
    return if connection.column_exists?(:references, :display_date)

    connection.add_column :references, :display_date, :string
  end

  def add_reference_tags(connection)
    return unless table_exists?(connection, :references)
    return if connection.column_exists?(:references, :tags)

    connection.add_column :references, :tags, :string, array: true, default: [], null: false
    connection.add_index :references, :tags, using: :gin
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
      table.string :slider_alt_text
      table.string :slider_sub_text
      table.string :slider_asset_path
      table.string :slider_file_path
      table.string :slider_content_type
      table.string :slider_filename
      table.bigint :slider_byte_size
      table.timestamps
    end

    connection.add_index :reference_images, :reference_id, unique: true
  end

  def add_reference_slider_image_fields(connection)
    return unless table_exists?(connection, :reference_images)

    {
      slider_alt_text: :string,
      slider_sub_text: :string,
      slider_asset_path: :string,
      slider_file_path: :string,
      slider_content_type: :string,
      slider_filename: :string,
      slider_byte_size: :bigint
    }.each do |column_name, type|
      next if connection.column_exists?(:reference_images, column_name)

      connection.add_column :reference_images, column_name, type
    end
  end

  def create_contacts(connection)
    return if table_exists?(connection, :contacts)

    connection.create_table :contacts do |table|
      table.string :name, null: false
      table.string :role
      table.string :phone_number, null: false
      table.string :email, null: false
      table.integer :position, default: 0, null: false
      table.timestamps
    end

    connection.add_index :contacts, :position
  end

  def create_contact_images(connection)
    return if table_exists?(connection, :contact_images)

    connection.create_table :contact_images do |table|
      table.references :contact, null: false
      image_columns(table)
    end

    connection.add_index :contact_images, :contact_id, unique: true
  end

  def create_jobs(connection)
    return if table_exists?(connection, :jobs)

    connection.create_table :jobs do |table|
      table.references :contact
      table.string :slug, null: false
      table.string :title, null: false
      table.string :badge
      table.string :employment
      table.string :location, null: false
      table.text :intro
      table.string :highlight_label
      table.string :highlight_title
      table.text :highlight_text
      table.text :responsibilities, array: true, default: [], null: false
      table.text :requirements, array: true, default: [], null: false
      table.string :categories, array: true, default: [], null: false
      table.string :join_recruiting_url
      table.string :meta_title
      table.text :meta_description
      table.string :status, default: "draft", null: false
      table.integer :position, default: 0, null: false
      table.timestamps
    end

    connection.add_index :jobs, :slug, unique: true
    connection.add_index :jobs, :status
    connection.add_index :jobs, :position
    connection.add_index :jobs, :categories, using: :gin
  end

  def create_job_images(connection)
    return if table_exists?(connection, :job_images)

    connection.create_table :job_images do |table|
      table.references :job, null: false
      image_columns(table)
    end

    connection.add_index :job_images, :job_id, unique: true
  end

  def image_columns(table)
    table.string :alt_text
    table.string :sub_text
    table.string :asset_path
    table.string :file_path
    table.string :content_type
    table.string :filename
    table.bigint :byte_size
    table.timestamps
  end

  def table_exists?(connection, table_name)
    connection.select_value("SELECT to_regclass(#{connection.quote(table_name.to_s)}) IS NOT NULL")
  end
end
