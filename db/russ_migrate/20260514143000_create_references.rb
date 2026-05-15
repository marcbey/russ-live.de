class CreateReferences < ActiveRecord::Migration[8.1]
  REFERENCES = [
    [ "DISGUSTING FOOD MUSEUM", "2026-04-18", "Stuttgart", "Karsten Jahnke Konzertdirektion", "Planung, Bewerbung und Betreuung für ein Projekt mit starkem Publikumszug.", "russ_live/references/01-disgusting-food-museum.jpg", "2x1" ],
    [ "DAVID GARRETT", "2025-05-21", "Liederhalle Stuttgart", "Live Nation", "Lokale Umsetzung mit präziser Abstimmung zwischen Produktion, Venue und Vermarktung.", "russ_live/references/02-david-garrett.jpg", "1x1" ],
    [ "NEIL YOUNG", "2024-06-29", "Hanns-Martin-Schleyer-Halle", "Wizart Promotion", "Kampagnenbetreuung, Ticketing und Ablaufkoordination aus einer Hand.", "russ_live/references/03-neil-young.jpg", "2x2" ],
    [ "IRON MAIDEN", "2023-07-13", "Porsche-Arena Stuttgart", "SKS Michael Russ", "Ein Abend mit dichtem Timetable, klarer Kommunikation und verlässlicher Produktion.", "russ_live/references/04-iron-maiden.jpg", "2x1" ],
    [ "Referenz 5", "2022-08-24", "SpardaWelt Freilichtbühne", "Semmel Concerts", "Regionale Aktivierung, Medienarbeit und Vor-Ort-Abwicklung im eingespielten Team.", "russ_live/references/05-referenz-5.jpg", "1x1" ],
    [ "TATE MC RAE", "2021-09-05", "Kultur- und Kongresszentrum", "BB Promotion", "Projektsteuerung für eine Veranstaltung mit besonderer Bühnen- und Besucherlogistik.", "russ_live/references/06-tate-mc-rae.jpg", "2x2" ],
    [ "SEAN PAUL", "2020-10-17", "Schlossplatz Stuttgart", "Karsten Jahnke Konzertdirektion", "Planung, Bewerbung und Betreuung für ein Projekt mit starkem Publikumszug.", "russ_live/references/07-sean-paul.jpg", "1x1" ],
    [ "CHRIS TALL", "2026-11-28", "Theaterhaus Stuttgart", "Live Nation", "Lokale Umsetzung mit präziser Abstimmung zwischen Produktion, Venue und Vermarktung.", "russ_live/references/08-chris-tall.jpg", "1x1" ],
    [ "MAX GIESINGER", "2025-04-18", "Stuttgart", "Wizart Promotion", "Kampagnenbetreuung, Ticketing und Ablaufkoordination aus einer Hand.", "russ_live/references/09-max-giesinger.jpg", "2x2" ],
    [ "SIMPLY RED", "2024-05-21", "Liederhalle Stuttgart", "SKS Michael Russ", "Ein Abend mit dichtem Timetable, klarer Kommunikation und verlässlicher Produktion.", "russ_live/references/10-simply-red.jpg", "1x1" ],
    [ "TOTO", "2023-06-29", "Hanns-Martin-Schleyer-Halle", "Semmel Concerts", "Regionale Aktivierung, Medienarbeit und Vor-Ort-Abwicklung im eingespielten Team.", "russ_live/references/11-toto.jpg", "1x1" ],
    [ "ACDC", "2022-07-13", "Porsche-Arena Stuttgart", "BB Promotion", "Projektsteuerung für eine Veranstaltung mit besonderer Bühnen- und Besucherlogistik.", "russ_live/references/12-acdc.jpg", "2x2" ],
    [ "GIANNA NANNINI", "2021-08-24", "SpardaWelt Freilichtbühne", "Karsten Jahnke Konzertdirektion", "Planung, Bewerbung und Betreuung für ein Projekt mit starkem Publikumszug.", "russ_live/references/13-gianna-nannini.jpg", "1x1" ],
    [ "BOB DYLAN", "2020-09-05", "Kultur- und Kongresszentrum", "Live Nation", "Lokale Umsetzung mit präziser Abstimmung zwischen Produktion, Venue und Vermarktung.", "russ_live/references/14-bob-dylan.jpg", "1x1" ],
    [ "LAURA PAUSINI", "2026-10-17", "Schlossplatz Stuttgart", "Wizart Promotion", "Kampagnenbetreuung, Ticketing und Ablaufkoordination aus einer Hand.", "russ_live/references/15-laura-pausini.jpg", "2x2" ],
    [ "TITANIC", "2025-11-28", "Theaterhaus Stuttgart", "SKS Michael Russ", "Ein Abend mit dichtem Timetable, klarer Kommunikation und verlässlicher Produktion.", "russ_live/references/16-titanic.jpg", "2x1" ],
    [ "MAMMA MIA!", "2024-04-18", "Stuttgart", "Semmel Concerts", "Regionale Aktivierung, Medienarbeit und Vor-Ort-Abwicklung im eingespielten Team.", "russ_live/references/17-mamma-mia.jpg", "1x1" ],
    [ "ADEL TAWIL", "2023-05-21", "Liederhalle Stuttgart", "BB Promotion", "Projektsteuerung für eine Veranstaltung mit besonderer Bühnen- und Besucherlogistik.", "russ_live/references/18-adel-tawil.jpg", "2x2" ],
    [ "BLUE MAN GROUP", "2022-06-29", "Hanns-Martin-Schleyer-Halle", "Karsten Jahnke Konzertdirektion", "Planung, Bewerbung und Betreuung für ein Projekt mit starkem Publikumszug.", "russ_live/references/19-blue-man-group.jpg", "1x1" ],
    [ "CRYSTAL - CIRQUE DU SOLEIL", "2021-07-13", "Porsche-Arena Stuttgart", "Live Nation", "Lokale Umsetzung mit präziser Abstimmung zwischen Produktion, Venue und Vermarktung.", "russ_live/references/20-crystal-cirque-du-soleil.jpg", "1x1" ],
    [ "HELENE FISCHER", "2020-08-24", "SpardaWelt Freilichtbühne", "Wizart Promotion", "Kampagnenbetreuung, Ticketing und Ablaufkoordination aus einer Hand.", "russ_live/references/21-helene-fischer.jpg", "2x1" ],
    [ "STUTTGART-LIVE FESTIVAL", "2026-09-05", "Kultur- und Kongresszentrum", "SKS Michael Russ", "Ein Abend mit dichtem Timetable, klarer Kommunikation und verlässlicher Produktion.", "russ_live/references/22-stuttgart-live-festival.png", "1x1" ],
    [ "Referenz 23", "2025-10-17", "Schlossplatz Stuttgart", "Semmel Concerts", "Regionale Aktivierung, Medienarbeit und Vor-Ort-Abwicklung im eingespielten Team.", "russ_live/references/23-referenz-23.jpg", "2x2" ],
    [ "CYPRESS HILL", "2024-11-28", "Theaterhaus Stuttgart", "BB Promotion", "Projektsteuerung für eine Veranstaltung mit besonderer Bühnen- und Besucherlogistik.", "russ_live/references/24-cypress-hill.jpg", "2x1" ],
    [ "SCORPIONS", "2023-04-18", "Stuttgart", "Karsten Jahnke Konzertdirektion", "Planung, Bewerbung und Betreuung für ein Projekt mit starkem Publikumszug.", "russ_live/references/25-scorpions.jpg", "1x1" ],
    [ "ERIC CLAPTON", "2022-05-21", "Liederhalle Stuttgart", "Live Nation", "Lokale Umsetzung mit präziser Abstimmung zwischen Produktion, Venue und Vermarktung.", "russ_live/references/26-eric-clapton.jpg", "2x2" ],
    [ "ZAZ", "2021-06-29", "Hanns-Martin-Schleyer-Halle", "Wizart Promotion", "Kampagnenbetreuung, Ticketing und Ablaufkoordination aus einer Hand.", "russ_live/references/27-zaz.jpg", "1x1" ],
    [ "HOWARD CARPENDALE", "2020-07-13", "Porsche-Arena Stuttgart", "SKS Michael Russ", "Ein Abend mit dichtem Timetable, klarer Kommunikation und verlässlicher Produktion.", "russ_live/references/28-howard-carpendale.jpg", "1x1" ],
    [ "KISS", "2026-08-24", "SpardaWelt Freilichtbühne", "Semmel Concerts", "Regionale Aktivierung, Medienarbeit und Vor-Ort-Abwicklung im eingespielten Team.", "russ_live/references/29-kiss.jpg", "2x1" ],
    [ "IRON MAIDEN", "2025-09-05", "Kultur- und Kongresszentrum", "BB Promotion", "Projektsteuerung für eine Veranstaltung mit besonderer Bühnen- und Besucherlogistik.", "russ_live/references/30-iron-maiden.jpg", "1x1" ],
    [ "MODERAT", "2024-10-17", "Schlossplatz Stuttgart", "Karsten Jahnke Konzertdirektion", "Planung, Bewerbung und Betreuung für ein Projekt mit starkem Publikumszug.", "russ_live/references/31-moderat.jpg", "2x2" ],
    [ "STUTTGART-LIVE FESTIVAL", "2023-11-28", "Theaterhaus Stuttgart", "Live Nation", "Lokale Umsetzung mit präziser Abstimmung zwischen Produktion, Venue und Vermarktung.", "russ_live/references/32-stuttgart-live-festival.png", "2x1" ],
    [ "KONTRA K", "2022-04-18", "Stuttgart", "Wizart Promotion", "Kampagnenbetreuung, Ticketing und Ablaufkoordination aus einer Hand.", "russ_live/references/33-kontra-k.jpg", "1x1" ],
    [ "VOLBEAT", "2021-05-21", "Liederhalle Stuttgart", "SKS Michael Russ", "Ein Abend mit dichtem Timetable, klarer Kommunikation und verlässlicher Produktion.", "russ_live/references/34-volbeat.jpg", "2x2" ],
    [ "Stuttgart-live Festival", "2020-06-29", "Hanns-Martin-Schleyer-Halle", "Semmel Concerts", "Regionale Aktivierung, Medienarbeit und Vor-Ort-Abwicklung im eingespielten Team.", "russ_live/references/35-stuttgart-live-festival.png", "1x1" ],
    [ "WWE LIVE", "2026-07-13", "Porsche-Arena Stuttgart", "BB Promotion", "Projektsteuerung für eine Veranstaltung mit besonderer Bühnen- und Besucherlogistik.", "russ_live/references/36-wwe-live.jpg", "1x1" ],
    [ "Kultur IM ALTEN SCHLOSS", "2025-08-24", "SpardaWelt Freilichtbühne", "Karsten Jahnke Konzertdirektion", "Planung, Bewerbung und Betreuung für ein Projekt mit starkem Publikumszug.", "russ_live/references/37-kultur-im-alten-schloss.jpg", "2x2" ],
    [ "Live Sommer - Autokonzerte für den Süden", "2024-09-05", "Kultur- und Kongresszentrum", "Live Nation", "Lokale Umsetzung mit präziser Abstimmung zwischen Produktion, Venue und Vermarktung.", "russ_live/references/38-live-sommer-autokonzerte-fuer-den-sueden.jpg", "2x1" ]
  ].freeze

  def change
    create_table :references do |t|
      t.string :title, null: false
      t.date :starts_on, null: false
      t.string :location, null: false
      t.string :production
      t.text :description
      t.string :status, default: "draft", null: false
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :references, :status
    add_index :references, [ :position, :starts_on ]

    create_table :reference_images do |t|
      t.references :reference, null: false, foreign_key: true, index: false
      t.string :alt_text
      t.string :sub_text
      t.string :grid_variant, default: "1x1", null: false
      t.decimal :card_focus_x, precision: 5, scale: 2, default: 50, null: false
      t.decimal :card_focus_y, precision: 5, scale: 2, default: 50, null: false
      t.decimal :card_zoom, precision: 5, scale: 2, default: 100, null: false
      t.string :asset_path
      t.string :file_path
      t.string :content_type
      t.string :filename
      t.bigint :byte_size

      t.timestamps
    end

    add_index :reference_images, :reference_id, unique: true

    reversible do |dir|
      dir.up { seed_references }
    end
  end

  private
    def seed_references
      now = Time.current

      REFERENCES.each_with_index do |row, index|
        title, starts_on, location, production, description, asset_path, grid_variant = row
        reference_id = insert_reference(title, starts_on, location, production, description, index, now)
        insert_reference_image(reference_id, title, asset_path, grid_variant, now)
      end
    end

    def insert_reference(title, starts_on, location, production, description, index, now)
      quoted_values = {
        title: quote(title),
        starts_on: quote(starts_on),
        location: quote(location),
        production: quote(production),
        description: quote(description),
        status: quote("published"),
        position: index + 1,
        created_at: quote(now),
        updated_at: quote(now)
      }

      select_value(<<~SQL.squish)
        INSERT INTO #{quote_table_name(:references)} (title, starts_on, location, production, description, status, position, created_at, updated_at)
        VALUES (#{quoted_values[:title]}, #{quoted_values[:starts_on]}, #{quoted_values[:location]}, #{quoted_values[:production]},
                #{quoted_values[:description]}, #{quoted_values[:status]}, #{quoted_values[:position]},
                #{quoted_values[:created_at]}, #{quoted_values[:updated_at]})
        RETURNING id
      SQL
    end

    def insert_reference_image(reference_id, title, asset_path, grid_variant, now)
      execute(<<~SQL.squish)
        INSERT INTO reference_images (reference_id, alt_text, grid_variant, card_focus_x, card_focus_y, card_zoom, asset_path, created_at, updated_at)
        VALUES (#{quote(reference_id)}, #{quote(title)}, #{quote(grid_variant)}, 50, 50, 100, #{quote(asset_path)}, #{quote(now)}, #{quote(now)})
      SQL
    end
end
