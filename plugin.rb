# frozen_string_literal: true

# name: discourse-csv-bulk-import
# about: Bulk import topics, replies, media, and ratings from a CSV file uploaded as a zip archive
# version: 0.0.1
# authors: Jahan Gagan
# url: https://github.com/jahan-ggn/discourse-csv-bulk-import

enabled_site_setting :discourse_csv_bulk_import_enabled

add_admin_route "csv_bulk_import.title", "csv-bulk-import"

module ::DiscourseCsvBulkImport
  PLUGIN_NAME = "discourse-csv-bulk-import"
end

require_relative "lib/discourse_csv_bulk_import/engine"

after_initialize do
  # Code which should run after Rails has finished booting
end
