class RemovePaulWoogFromLegalPages < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE editable_pages
      SET
        content = CASE
          WHEN COALESCE(content->>'body_html', '') LIKE '%Paul Woog%'
            THEN jsonb_set(
              content,
              '{body_html}',
              to_jsonb(REPLACE(REPLACE(REPLACE(content->>'body_html', 'Michaela Russ, Paul Woog', 'Michaela Russ'), 'Paul Woog, Michaela Russ', 'Michaela Russ'), 'Paul Woog', ''))
            )
          ELSE content
        END,
        published_content = CASE
          WHEN COALESCE(published_content->>'body_html', '') LIKE '%Paul Woog%'
            THEN jsonb_set(
              published_content,
              '{body_html}',
              to_jsonb(REPLACE(REPLACE(REPLACE(published_content->>'body_html', 'Michaela Russ, Paul Woog', 'Michaela Russ'), 'Paul Woog, Michaela Russ', 'Michaela Russ'), 'Paul Woog', ''))
            )
          ELSE published_content
        END,
        updated_at = CURRENT_TIMESTAMP
      WHERE key IN ('impressum', 'datenschutz')
        AND (
          COALESCE(content->>'body_html', '') LIKE '%Paul Woog%'
          OR COALESCE(published_content->>'body_html', '') LIKE '%Paul Woog%'
        )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
