class CreateAuthSessionsAndLoginAttempts < ActiveRecord::Migration[8.1]
  def change
    create_table :sessions do |t|
      t.bigint :user_id, null: false
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end

    add_index :sessions, :user_id

    create_table :login_attempts do |t|
      t.bigint :user_id
      t.string :email_address
      t.string :ip_address
      t.string :user_agent
      t.string :outcome, null: false

      t.timestamps
    end

    add_index :login_attempts, :created_at
    add_index :login_attempts, [ :email_address, :created_at ]
    add_index :login_attempts, [ :outcome, :created_at ]
    add_index :login_attempts, :user_id
  end
end
