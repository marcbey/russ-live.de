class PagesController < ApplicationController
  PAGE_META = {
    home: {
      title: "Russ Live | Kulturproduktionen auf höchstem Niveau",
      description: "Russ Live ist örtlicher Veranstalter, Produktionspartner und Full-Service-Dienstleister für Live Entertainment in Stuttgart und der Region.",
      body_class: "home-body"
    },
    unternehmen: {
      title: "Über uns | Russ Live",
      description: "Über Russ Live: Geschichte, Haltung und Menschen hinter den Veranstaltungen."
    },
    services: {
      title: "Services | Russ Live",
      body_class: "services-body"
    },
    referenzen: {
      title: "Referenzen | Russ Live",
      body_class: "references-body"
    },
    jobs: {
      title: "Cateringhilfen | Jobs | Russ Live",
      description: "Cateringhilfen auf Minijob-Basis bei Russ Live: Tätigkeitsfeld, Anforderungen und Ansprechpartner für Deine Bewerbung.",
      body_class: "jobs-body"
    },
    presse: {
      title: "Presse | Russ Live",
      body_class: "press-body"
    },
    press_detail: {
      title: "Presse Detail | Russ Live",
      body_class: "press-body"
    },
    kontakt: {
      title: "Kontakt | Russ Live",
      description: "Kontakt zur SKS Michael Russ GmbH am Charlottenplatz in Stuttgart."
    },
    impressum: {
      title: "Impressum | Russ Live",
      description: "Impressum der SKS Michael Russ GmbH."
    },
    datenschutz: {
      title: "Datenschutz | Russ Live",
      description: "Datenschutz der SKS Michael Russ GmbH."
    },
    agb: {
      title: "AGB | Russ Live",
      description: "AGB der SKS Michael Russ GmbH."
    },
    jugendschutz: {
      title: "Jugendschutz | Russ Live",
      description: "Jugendschutz der SKS Michael Russ GmbH."
    }
  }.freeze

  PRESS_ARTIST_GROUPS = {
    "1" => [ "1019" ],
    "A" => [ "A Tribute To Taylor Swift: Lover", "All Them Witches", "Andreas Gabalier" ],
    "B" => [ "Blue", "Brunke" ],
    "C" => [ "Call It Off" ],
    "D" => [ "Das Lumpenpack", "David Garrett", "Dirk Steffens", "Dittsche", "Dú Maroc" ],
    "E" => [ "Elif" ],
    "F" => [ "Faroon", "Five Finger Death Punch" ],
    "G" => [ "Gestört aber Geil", "Glueboys", "Gregory Porter & Band" ],
    "J" => [ "Jolle" ],
    "K" => [ "Kati K", "Kiss Forever Band", "Kolja Goldstein" ],
    "L" => [ "Lake Street Dive", "LEA", "Levka", "Lina", "Luvre47" ],
    "M" => [ "Mamma Mia! - Das Original-Musical", "Mammoth", "Mathias Richling", "Melrose Avenue", "Mike Oldfield's Tubular Bells" ],
    "N" => [ "Niklas Dee", "Nimo", "Nizi19", "Not Scientists" ],
    "P" => [ "PaulK", "Pitbull" ],
    "R" => [ "Rea Garvey's Christmas Calling 2026" ],
    "S" => [ "Saliou", "Sascha Lange", "Slaughter To Prevail", "Starbenders", "Steel Panther" ],
    "T" => [ "tAKiDA", "The Kilkennys", "The Music Of Genesis", "Tjark", "Truckfighters", "Twin Noir" ],
    "V" => [ "Vier Pianisten – Ein Konzert", "voXXclub" ],
    "W" => [ "Wilhelmine" ],
    "Y" => [ "Yaris" ],
    "Z" => [ "Zuna", "Zymba" ]
  }.freeze

  HOME_REFERENCES = [
    { image: "russ_live/references/01-disgusting-food-museum.jpg", alt: "DISGUSTING FOOD MUSEUM", title: "DISGUSTING FOOD MUSEUM", date_location: "18.04.2026 · Stuttgart", partner: "Partner: Karsten Jahnke Konzertdirektion" },
    { image: "russ_live/references/02-david-garrett.jpg", alt: "DAVID GARRETT", title: "DAVID GARRETT", date_location: "21.05.2025 · Liederhalle Stuttgart", partner: "Partner: Live Nation" },
    { image: "russ_live/references/03-neil-young.jpg", alt: "NEIL YOUNG", title: "NEIL YOUNG", date_location: "29.06.2024 · Hanns-Martin-Schleyer-Halle", partner: "Partner: Wizart Promotion" },
    { image: "russ_live/references/04-iron-maiden.jpg", alt: "IRON MAIDEN", title: "IRON MAIDEN", date_location: "13.07.2023 · Porsche-Arena Stuttgart", partner: "Partner: SKS Michael Russ" },
    { image: "russ_live/references/05-referenz-5.jpg", alt: "Referenz 5", title: "Referenz 5", date_location: "24.08.2022 · SpardaWelt Freilichtbühne", partner: "Partner: Semmel Concerts" },
    { image: "russ_live/references/06-tate-mc-rae.jpg", alt: "TATE MC RAE", title: "TATE MC RAE", date_location: "05.09.2021 · Kultur- und Kongresszentrum", partner: "Partner: BB Promotion" },
    { image: "russ_live/references/07-sean-paul.jpg", alt: "SEAN PAUL", title: "SEAN PAUL", date_location: "17.10.2020 · Schlossplatz Stuttgart", partner: "Partner: Karsten Jahnke Konzertdirektion" },
    { image: "russ_live/references/08-chris-tall.jpg", alt: "CHRIS TALL", title: "CHRIS TALL", date_location: "28.11.2026 · Theaterhaus Stuttgart", partner: "Partner: Live Nation" },
    { image: "russ_live/references/09-max-giesinger.jpg", alt: "MAX GIESINGER", title: "MAX GIESINGER", date_location: "18.04.2025 · Stuttgart", partner: "Partner: Wizart Promotion" },
    { image: "russ_live/references/10-simply-red.jpg", alt: "SIMPLY RED", title: "SIMPLY RED", date_location: "21.05.2024 · Liederhalle Stuttgart", partner: "Partner: SKS Michael Russ" },
    { image: "russ_live/references/11-toto.jpg", alt: "TOTO", title: "TOTO", date_location: "29.06.2023 · Hanns-Martin-Schleyer-Halle", partner: "Partner: Semmel Concerts" },
    { image: "russ_live/references/12-acdc.jpg", alt: "ACDC", title: "ACDC", date_location: "13.07.2022 · Porsche-Arena Stuttgart", partner: "Partner: BB Promotion" },
    { image: "russ_live/references/13-gianna-nannini.jpg", alt: "GIANNA NANNINI", title: "GIANNA NANNINI", date_location: "24.08.2021 · SpardaWelt Freilichtbühne", partner: "Partner: Karsten Jahnke Konzertdirektion" },
    { image: "russ_live/references/14-bob-dylan.jpg", alt: "BOB DYLAN", title: "BOB DYLAN", date_location: "05.09.2020 · Kultur- und Kongresszentrum", partner: "Partner: Live Nation" },
    { image: "russ_live/references/15-laura-pausini.jpg", alt: "LAURA PAUSINI", title: "LAURA PAUSINI", date_location: "17.10.2026 · Schlossplatz Stuttgart", partner: "Partner: Wizart Promotion" },
    { image: "russ_live/references/16-titanic.jpg", alt: "TITANIC", title: "TITANIC", date_location: "28.11.2025 · Theaterhaus Stuttgart", partner: "Partner: SKS Michael Russ" },
    { image: "russ_live/references/17-mamma-mia.jpg", alt: "MAMMA MIA!", title: "MAMMA MIA!", date_location: "18.04.2024 · Stuttgart", partner: "Partner: Semmel Concerts" },
    { image: "russ_live/references/18-adel-tawil.jpg", alt: "ADEL TAWIL", title: "ADEL TAWIL", date_location: "21.05.2023 · Liederhalle Stuttgart", partner: "Partner: BB Promotion" },
    { image: "russ_live/references/19-blue-man-group.jpg", alt: "BLUE MAN GROUP", title: "BLUE MAN GROUP", date_location: "29.06.2022 · Hanns-Martin-Schleyer-Halle", partner: "Partner: Karsten Jahnke Konzertdirektion" },
    { image: "russ_live/references/20-crystal-cirque-du-soleil.jpg", alt: "CRYSTAL - CIRQUE DU SOLEIL", title: "CRYSTAL - CIRQUE DU SOLEIL", date_location: "13.07.2021 · Porsche-Arena Stuttgart", partner: "Partner: Live Nation" },
    { image: "russ_live/references/21-helene-fischer.jpg", alt: "HELENE FISCHER", title: "HELENE FISCHER", date_location: "24.08.2020 · SpardaWelt Freilichtbühne", partner: "Partner: Wizart Promotion" },
    { image: "russ_live/references/22-stuttgart-live-festival.png", alt: "STUTTGART-LIVE FESTIVAL", title: "STUTTGART-LIVE FESTIVAL", date_location: "05.09.2026 · Kultur- und Kongresszentrum", partner: "Partner: SKS Michael Russ" },
    { image: "russ_live/references/23-referenz-23.jpg", alt: "Referenz 23", title: "Referenz 23", date_location: "17.10.2025 · Schlossplatz Stuttgart", partner: "Partner: Semmel Concerts" },
    { image: "russ_live/references/24-cypress-hill.jpg", alt: "CYPRESS HILL", title: "CYPRESS HILL", date_location: "28.11.2024 · Theaterhaus Stuttgart", partner: "Partner: BB Promotion" },
    { image: "russ_live/references/25-scorpions.jpg", alt: "SCORPIONS", title: "SCORPIONS", date_location: "18.04.2023 · Stuttgart", partner: "Partner: Karsten Jahnke Konzertdirektion" },
    { image: "russ_live/references/26-eric-clapton.jpg", alt: "ERIC CLAPTON", title: "ERIC CLAPTON", date_location: "21.05.2022 · Liederhalle Stuttgart", partner: "Partner: Live Nation" },
    { image: "russ_live/references/27-zaz.jpg", alt: "ZAZ", title: "ZAZ", date_location: "29.06.2021 · Hanns-Martin-Schleyer-Halle", partner: "Partner: Wizart Promotion" },
    { image: "russ_live/references/28-howard-carpendale.jpg", alt: "HOWARD CARPENDALE", title: "HOWARD CARPENDALE", date_location: "13.07.2020 · Porsche-Arena Stuttgart", partner: "Partner: SKS Michael Russ" },
    { image: "russ_live/references/29-kiss.jpg", alt: "KISS", title: "KISS", date_location: "24.08.2026 · SpardaWelt Freilichtbühne", partner: "Partner: Semmel Concerts" },
    { image: "russ_live/references/30-iron-maiden.jpg", alt: "IRON MAIDEN", title: "IRON MAIDEN", date_location: "05.09.2025 · Kultur- und Kongresszentrum", partner: "Partner: BB Promotion" },
    { image: "russ_live/references/31-moderat.jpg", alt: "MODERAT", title: "MODERAT", date_location: "17.10.2024 · Schlossplatz Stuttgart", partner: "Partner: Karsten Jahnke Konzertdirektion" },
    { image: "russ_live/references/32-stuttgart-live-festival.png", alt: "STUTTGART-LIVE FESTIVAL", title: "STUTTGART-LIVE FESTIVAL", date_location: "28.11.2023 · Theaterhaus Stuttgart", partner: "Partner: Live Nation" },
    { image: "russ_live/references/33-kontra-k.jpg", alt: "KONTRA K", title: "KONTRA K", date_location: "18.04.2022 · Stuttgart", partner: "Partner: Wizart Promotion" },
    { image: "russ_live/references/34-volbeat.jpg", alt: "VOLBEAT", title: "VOLBEAT", date_location: "21.05.2021 · Liederhalle Stuttgart", partner: "Partner: SKS Michael Russ" },
    { image: "russ_live/references/35-stuttgart-live-festival.png", alt: "Stuttgart-live Festival", title: "Stuttgart-live Festival", date_location: "29.06.2020 · Hanns-Martin-Schleyer-Halle", partner: "Partner: Semmel Concerts" },
    { image: "russ_live/references/36-wwe-live.jpg", alt: "WWE LIVE", title: "WWE LIVE", date_location: "13.07.2026 · Porsche-Arena Stuttgart", partner: "Partner: BB Promotion" },
    { image: "russ_live/references/37-kultur-im-alten-schloss.jpg", alt: "Kultur IM ALTEN SCHLOSS", title: "Kultur IM ALTEN SCHLOSS", date_location: "24.08.2025 · SpardaWelt Freilichtbühne", partner: "Partner: Karsten Jahnke Konzertdirektion" },
    { image: "russ_live/references/38-live-sommer-autokonzerte-fuer-den-sueden.jpg", alt: "Live Sommer - Autokonzerte für den Süden", title: "Live Sommer - Autokonzerte für den Süden", date_location: "05.09.2024 · Kultur- und Kongresszentrum", partner: "Partner: Live Nation" }
  ].freeze

  HOME_EVENTS = [
    { image: "russ_live/references/09-max-giesinger.jpg", title: "Wilhelmine", date_location: "23. Mai 2026 · Im Wizemann", tour: "Alles, was du träumst Tour", ticket_label: "Tickets", ticket_url: "https://stuttgart-live.de/" },
    { image: "russ_live/references/31-moderat.jpg", title: "Truckfighters", date_location: "25. Mai 2026 · Im Wizemann", tour: "European Run 2026", ticket_label: "Tickets", ticket_url: "https://stuttgart-live.de/" },
    { image: "russ_live/references/24-cypress-hill.jpg", title: "Truckfighters", date_location: "26. Mai 2026 · Im Wizemann", tour: "Special Club Show", ticket_label: "Tickets", ticket_url: "https://stuttgart-live.de/" },
    { image: "russ_live/references/33-kontra-k.jpg", title: "1019", date_location: "05. Juni 2026 · Im Wizemann", tour: "Live 2026", ticket_label: "Tickets", ticket_url: "https://stuttgart-live.de/" },
    { image: "russ_live/references/10-simply-red.jpg", title: "Melrose Avenue", date_location: "16. Juni 2026 · Kulturquartier", tour: "Summer Nights", ticket_label: "Tickets", ticket_url: "https://stuttgart-live.de/" }
  ].freeze

  before_action :set_page_meta

  def home
    @home_references = HOME_REFERENCES
    @home_events = HOME_EVENTS
  end
  def unternehmen; end
  def services; end
  def referenzen; end
  def jobs; end
  def presse
    @press_artist_groups = PRESS_ARTIST_GROUPS
    @press_artist_count = PRESS_ARTIST_GROUPS.values.sum(&:size)
  end

  def press_detail; end
  def kontakt; end
  def impressum; end
  def datenschutz; end
  def agb; end
  def jugendschutz; end

  private

  def set_page_meta
    @page_key = action_name.to_sym
    @page_meta = PAGE_META.fetch(@page_key)
  end
end
