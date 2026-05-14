class AppSetting < SharedStuttgartRecord
  SKS_PROMOTER_IDS_KEY = "sks_promoter_ids".freeze

  self.table_name = "app_settings"

  class << self
    def sks_promoter_ids
      normalize_id_list(find_by(key: SKS_PROMOTER_IDS_KEY)&.value)
    rescue ActiveRecord::StatementInvalid
      []
    end

    private

    def normalize_id_list(value)
      Array.wrap(value).flat_map { |entry| entry.to_s.split(/[,;\r\n]+/) }.map(&:strip).compact_blank.uniq
    end
  end
end
