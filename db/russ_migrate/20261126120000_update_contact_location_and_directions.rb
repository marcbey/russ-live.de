class UpdateContactLocationAndDirections < ActiveRecord::Migration[8.1]
  REPLACEMENTS = {
    "de" => [
      [ "Die Konzertdirektion Russ befindet sich im Herzen der Stuttgarter Innenstadt am Charlottenplatz 17. In direkter Nachbarschaft liegen das Neue Schloss und das Landesmuseum Württemberg.", "Die Konzertdirektion Russ befindet sich mitten in Stuttgart am Charlottenplatz 17. Gleich nebenan liegen das ifa und das Amadeus im ruhigen Innenhof des Alten Waisenhauses." ],
      [ " Hier geht es zum Fahrplan.", "" ]
    ],
    "en" => [
      [ "Konzertdirektion Russ is located in the heart of downtown Stuttgart at Charlottenplatz 17. The New Palace and the Landesmuseum Württemberg are nearby.", "Konzertdirektion Russ is located in central Stuttgart at Charlottenplatz 17. Right next door are the ifa and Amadeus in the quiet courtyard of the Old Orphanage (Altes Waisenhaus)." ],
      [ " This is the way to the timetable.", "" ]
    ]
  }.freeze

  def up
    REPLACEMENTS.each do |locale, replacements|
      %w[content published_content].each do |column|
        %w[body_html location directions].each do |field|
          replacements.each do |old_text, new_text|
            execute <<~SQL
              UPDATE editable_pages
              SET #{column} = jsonb_set(
                #{column}, '{#{field}}',
                to_jsonb(REPLACE(#{column}->>'#{field}', #{connection.quote(old_text)}, #{connection.quote(new_text)}))
              ), updated_at = CURRENT_TIMESTAMP
              WHERE key = 'kontakt' AND locale = #{connection.quote(locale)}
                AND STRPOS(COALESCE(#{column}->>'#{field}', ''), #{connection.quote(old_text)}) > 0
            SQL
          end
        end
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Later editorial changes must not be overwritten."
  end
end
