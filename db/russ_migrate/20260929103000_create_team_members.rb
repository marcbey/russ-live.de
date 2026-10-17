class CreateTeamMembers < ActiveRecord::Migration[8.1]
  MEMBERS = [
    [ "Michaela Russ", "Geschäftsleitung", "Management", "michaela-russ.jpg" ],
    [ "Johanna Backmund", "Projektmanagement / Accounting", "Project Management / Accounting", "johanna-backmund.jpg" ],
    [ "Tim Wilka", "Ticketing", "Ticketing", "tim-wilka.jpg" ],
    [ "Sarah Sandner", "Team Lead Marketing", "Team Lead Marketing", "sarah-sandner.jpg" ],
    [ "Chantal Erler", "Marketing Online / Social Media", "Online Marketing / Social Media", "chantal-erler.jpg" ],
    [ "Katharina Schopper", "Grafik / Layout", "Graphic Design / Layout", "katharina-schopper.jpg" ],
    [ "Arnulf Woock", "Presse- & Öffentlichkeitsarbeit", "Press & Public Relations", "arnulf-woock.jpg" ],
    [ "Michael Wechselberger", "Personaldisposition", "Staff Scheduling", "michael-wechselberger.jpg" ],
    [ "Tanja Ullenboom", "Produktionsleitung", "Production Management", "tanja-ullenboom.jpg" ],
    [ "Jenny Hefner", "Buchhaltung", "Accounting", "jenny-hefner.jpg" ]
  ].freeze

  def change
    create_table :team_members do |t|
      t.string :name, null: false
      t.string :role
      t.string :role_en
      t.integer :position, default: 0, null: false
      t.timestamps
    end
    add_index :team_members, :position

    create_table :team_member_images do |t|
      t.references :team_member, null: false, foreign_key: true, index: false
      t.string :alt_text
      t.string :sub_text
      t.string :asset_path
      t.string :file_path
      t.string :content_type
      t.string :filename
      t.bigint :byte_size
      t.timestamps
    end
    add_index :team_member_images, :team_member_id, unique: true

    reversible { |dir| dir.up { seed_team_members } }
  end

  private
    def seed_team_members
      now = Time.current
      MEMBERS.each_with_index do |(name, role, role_en, filename), index|
        member_id = select_value(<<~SQL.squish)
          INSERT INTO team_members (name, role, role_en, position, created_at, updated_at)
          VALUES (#{quote(name)}, #{quote(role)}, #{quote(role_en)}, #{index + 1}, #{quote(now)}, #{quote(now)})
          RETURNING id
        SQL
        execute(<<~SQL.squish)
          INSERT INTO team_member_images (team_member_id, alt_text, asset_path, created_at, updated_at)
          VALUES (#{quote(member_id)}, #{quote(name)}, #{quote("russ_live/team/#{filename}")}, #{quote(now)}, #{quote(now)})
        SQL
      end
    end
end
