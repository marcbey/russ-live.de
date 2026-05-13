class PagesController < ApplicationController
  PAGE_META = {
    home: {
      title: "Russ Live | Kulturproduktionen auf höchstem Niveau",
      description: "Russ Live ist örtlicher Veranstalter, Produktionspartner und Full-Service-Dienstleister für Live Entertainment in Stuttgart und der Region."
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

  before_action :set_page_meta

  def home; end
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
