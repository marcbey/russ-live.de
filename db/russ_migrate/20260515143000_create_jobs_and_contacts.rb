class CreateJobsAndContacts < ActiveRecord::Migration[8.1]
  CONTACT = {
    name: "Sebastian Kränzlein",
    role: "Personaldisposition / Personalmarketing",
    phone_number: "+49.711.16 353 42",
    email: "sebastiankraenzlein@russ-live.de",
    image: "russ_live/team/sebastian-kraenzlein.jpg"
  }.freeze

  JOBS = [
    {
      slug: "cateringhilfen",
      title: "Cateringhilfen",
      badge: "Minijob",
      meta_title: "Cateringhilfen | Jobs | Russ Live",
      meta_description: "Cateringhilfen auf Minijob-Basis bei Russ Live: Tätigkeitsfeld, Anforderungen und Ansprechpartner für Deine Bewerbung.",
      employment: "Zum nächstmöglichen Zeitpunkt, auf Minijob-Basis, m/w/d",
      categories: [ "Catering" ],
      location: "Stuttgart",
      intro: "Du unterstützt unser Team hinter den Kulissen und sorgst dafür, dass Crew, Künstler*innen und Gäste zuverlässig versorgt werden.",
      hero_image: "russ_live/jobs/cateringhilfen.jpg",
      hero_image_alt: "Küchenteam bereitet frische Speisen zu",
      highlight_label: "Einzigartige Momente",
      highlight_title: "Arbeiten, wo Events entstehen.",
      highlight_text: "Vom ersten Aufbau bis zur letzten Show bist Du Teil eingespielter Teams und echter Live-Momente.",
      responsibilities: [
        "Hilfstätigkeiten bei der Speisenzubereitung",
        "Auf- und Abbau von Buffets",
        "Unterstützung des Küchenteams"
      ],
      requirements: [
        "Zuverlässiges, gewissenhaftes Arbeiten",
        "Flexibilität auch spät abends oder nachts zu arbeiten",
        "Körperliche Fitness",
        "Team- und gute Kommunikationsfähigkeit",
        "Schnelle Auffassungsgabe",
        "Englischkenntnisse von Vorteil",
        "Motivation und Lust auf Arbeiten in der Event-Branche",
        "Gültiges allgemeines Gesundheitszeugnis"
      ]
    },
    {
      slug: "stagehands",
      title: "Stagehands",
      badge: "Minijob",
      meta_title: "Stagehands | Jobs | Russ Live",
      meta_description: "Stagehands auf Minijob-Basis bei Russ Live: Einsatzbereiche, Anforderungen und Bewerbung.",
      employment: "Flexible Einsätze bei Konzerten und Produktionen, m/w/d",
      categories: [ "Auf-/Abbau" ],
      location: "Stuttgart",
      intro: "Du packst an, wenn Bühnen, Backstage-Bereiche und Produktionen aufgebaut, umgebaut und wieder abgebaut werden.",
      hero_image: "russ_live/jobs/cateringhilfen.jpg",
      hero_image_alt: "Team bei der Arbeit in einer Produktionsküche",
      highlight_label: "Teamwork in Bewegung",
      highlight_title: "Mitten in der Live-Produktion.",
      highlight_text: "Du bist dort, wo Technik, Timing und Teamarbeit zusammenspielen und jede Show vorbereitet wird.",
      responsibilities: [
        "Unterstützung beim Auf- und Abbau von Bühnen-, Licht- und Tontechnik",
        "Transport und Positionierung von Material im Venue",
        "Mithilfe bei Umbauten während laufender Produktionen"
      ],
      requirements: [
        "Körperliche Belastbarkeit und Freude an praktischer Arbeit",
        "Zuverlässigkeit und Pünktlichkeit bei wechselnden Einsatzzeiten",
        "Teamfähigkeit und respektvoller Umgang am Set",
        "Sicheres Arbeiten auch unter Zeitdruck",
        "Erste Erfahrung im Veranstaltungsbereich ist hilfreich, aber kein Muss"
      ]
    },
    {
      slug: "staplerfahrer-innen",
      title: "Staplerfahrer*innen",
      badge: "Minijob",
      meta_title: "Staplerfahrer*innen | Jobs | Russ Live",
      meta_description: "Staplerfahrer*innen für Eventproduktionen bei Russ Live: Aufgaben, Anforderungen und Bewerbung.",
      employment: "Flexible Einsätze auf Minijob-Basis, m/w/d",
      categories: [ "Logistik" ],
      location: "Stuttgart",
      intro: "Du bewegst Material sicher über das Gelände und unterstützt unsere Teams bei logistischen Abläufen rund um Events.",
      hero_image: "russ_live/jobs/cateringhilfen.jpg",
      hero_image_alt: "Team bei der Arbeit in einer Produktionsküche",
      highlight_label: "Logistik mit Überblick",
      highlight_title: "Präzision hinter großen Shows.",
      highlight_text: "Mit ruhiger Hand und guter Abstimmung sorgst Du dafür, dass Material pünktlich am richtigen Ort ankommt.",
      responsibilities: [
        "Be- und Entladen von Veranstaltungs- und Produktionsequipment",
        "Sicherer Transport von Material auf dem Gelände",
        "Unterstützung der Lager- und Logistikteams vor Ort"
      ],
      requirements: [
        "Gültiger Staplerschein",
        "Verantwortungsbewusstes und umsichtiges Arbeiten",
        "Bereitschaft zu Einsätzen auch am Abend oder Wochenende",
        "Abstimmungssicherheit im Team und mit Gewerken vor Ort",
        "Erfahrung im Event- oder Logistikumfeld von Vorteil"
      ]
    },
    {
      slug: "securities",
      title: "Securities",
      badge: "Minijob",
      meta_title: "Securities | Jobs | Russ Live",
      meta_description: "Security-Jobs bei Russ Live: Einsatzorte, Anforderungen und Ansprechpartner für Deine Bewerbung.",
      employment: "Flexible Einsätze für Veranstaltungen, m/w/d",
      categories: [ "Security" ],
      location: "Stuttgart",
      intro: "Du sorgst mit Übersicht, Ruhe und Präsenz für einen sicheren Ablauf bei Einlass, Besucherführung und Produktion.",
      hero_image: "russ_live/jobs/cateringhilfen.jpg",
      hero_image_alt: "Team bei der Arbeit in einer Produktionsküche",
      highlight_label: "Verantwortung vor Ort",
      highlight_title: "Sicherheit für besondere Abende.",
      highlight_text: "Du bist Ansprechpartner*in für Gäste und Teil eines Teams, das auch in dynamischen Situationen einen kühlen Kopf behält.",
      responsibilities: [
        "Unterstützung bei Einlass- und Kontrollsituationen",
        "Ansprechpartner*in für Besucher*innen und Teams vor Ort",
        "Mitwirkung an geordneten Abläufen in Publikums- und Backstagebereichen"
      ],
      requirements: [
        "Freundliches, souveränes Auftreten",
        "Zuverlässigkeit und Verantwortungsbewusstsein",
        "Kommunikationsstärke und Deeskalationsfähigkeit",
        "Bereitschaft zu Abend-, Wochenend- und Feiertagseinsätzen",
        "Unterrichtung oder Sachkunde nach Paragraph 34a ist von Vorteil"
      ]
    }
  ].freeze

  def change
    create_table :contacts do |t|
      t.string :name, null: false
      t.string :role
      t.string :phone_number, null: false
      t.string :email, null: false
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :contacts, :position

    create_table :contact_images do |t|
      t.references :contact, null: false, foreign_key: true, index: false
      image_columns(t)
    end

    add_index :contact_images, :contact_id, unique: true

    create_table :jobs do |t|
      t.references :contact, foreign_key: true
      t.string :slug, null: false
      t.string :title, null: false
      t.string :badge
      t.string :employment
      t.string :location, null: false
      t.text :intro
      t.string :highlight_label
      t.string :highlight_title
      t.text :highlight_text
      t.text :responsibilities, array: true, default: [], null: false
      t.text :requirements, array: true, default: [], null: false
      t.string :categories, array: true, default: [], null: false
      t.string :join_recruiting_url
      t.string :meta_title
      t.text :meta_description
      t.string :status, default: "draft", null: false
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :jobs, :slug, unique: true
    add_index :jobs, :status
    add_index :jobs, :position
    add_index :jobs, :categories, using: :gin

    create_table :job_images do |t|
      t.references :job, null: false, foreign_key: true, index: false
      image_columns(t)
    end

    add_index :job_images, :job_id, unique: true

    reversible do |dir|
      dir.up { seed_jobs_and_contacts }
    end
  end

  private
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

    def seed_jobs_and_contacts
      now = Time.current
      contact_id = insert_contact(now)
      insert_contact_image(contact_id, now)

      JOBS.each_with_index do |job, index|
        job_id = insert_job(job, contact_id, index, now)
        insert_job_image(job_id, job, now)
      end
    end

    def insert_contact(now)
      select_value(<<~SQL.squish)
        INSERT INTO contacts (name, role, phone_number, email, position, created_at, updated_at)
        VALUES (#{quote(CONTACT[:name])}, #{quote(CONTACT[:role])}, #{quote(CONTACT[:phone_number])},
                #{quote(CONTACT[:email])}, 1, #{quote(now)}, #{quote(now)})
        RETURNING id
      SQL
    end

    def insert_contact_image(contact_id, now)
      execute(<<~SQL.squish)
        INSERT INTO contact_images (contact_id, alt_text, asset_path, created_at, updated_at)
        VALUES (#{quote(contact_id)}, #{quote(CONTACT[:name])}, #{quote(CONTACT[:image])}, #{quote(now)}, #{quote(now)})
      SQL
    end

    def insert_job(job, contact_id, index, now)
      select_value(<<~SQL.squish)
        INSERT INTO jobs (
          contact_id, slug, title, badge, employment, location, intro, highlight_label, highlight_title,
          highlight_text, responsibilities, requirements, categories, join_recruiting_url,
          meta_title, meta_description, status, position, created_at, updated_at
        )
        VALUES (
          #{quote(contact_id)}, #{quote(job[:slug])}, #{quote(job[:title])}, #{quote(job[:badge])},
          #{quote(job[:employment])}, #{quote(job[:location])}, #{quote(job[:intro])},
          #{quote(job[:highlight_label])}, #{quote(job[:highlight_title])}, #{quote(job[:highlight_text])},
          #{quote_text_array(job[:responsibilities])}, #{quote_text_array(job[:requirements])},
          #{quote_string_array(job[:categories])}, NULL, #{quote(job[:meta_title])},
          #{quote(job[:meta_description])}, 'published', #{index + 1}, #{quote(now)}, #{quote(now)}
        )
        RETURNING id
      SQL
    end

    def insert_job_image(job_id, job, now)
      execute(<<~SQL.squish)
        INSERT INTO job_images (job_id, alt_text, asset_path, created_at, updated_at)
        VALUES (#{quote(job_id)}, #{quote(job[:hero_image_alt])}, #{quote(job[:hero_image])}, #{quote(now)}, #{quote(now)})
      SQL
    end

    def quote_string_array(values)
      "ARRAY[#{values.map { |value| quote(value) }.join(',')}]::varchar[]"
    end

    def quote_text_array(values)
      "ARRAY[#{values.map { |value| quote(value) }.join(',')}]::text[]"
    end
end
