# frozen_string_literal: true

module Jobs
  class CleanupImportStatus < ::Jobs::Scheduled
    every 1.day

    RETENTION_DAYS = 7

    def execute(args)
      cutoff = RETENTION_DAYS.days.ago

      rows = PluginStoreRow.where(plugin_name: ::DiscourseCsvBulkImport::PLUGIN_NAME)
                           .where("key LIKE 'import_status_%'")

      deleted = 0
      rows.find_each do |row|
        data = JSON.parse(row.value) rescue nil
        next if data.nil?

        updated_at = Time.zone.parse(data["updated_at"]) rescue nil
        next if updated_at.nil? || updated_at > cutoff

        row.destroy
        deleted += 1
      end

      Rails.logger.info("[CsvBulkImport] Cleaned up #{deleted} old import status records") if deleted > 0
    end
  end
end
