class BackfillReferenceStartsOnFromDisplayDate < ActiveRecord::Migration[8.1]
  def up
    Reference.reset_column_information

    Reference.where.not(display_date: [ nil, "" ]).find_each do |reference|
      sort_date = Reference.sort_date_from_display_date(reference.display_date)
      next if sort_date.blank? || reference.starts_on == sort_date

      reference.update_columns(starts_on: sort_date, updated_at: reference.updated_at)
    end
  end

  def down
    # Existing dates cannot be restored reliably because display_date is free text.
  end
end
