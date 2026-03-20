# frozen_string_literal: true

module Jobs
  class RunCsvImport < ::Jobs::Base
    sidekiq_options retry: false

    BATCH_SIZE = 25

    def execute(args)
      @job_id = args[:job_id]
      @csv_path = args[:csv_path]
      @images_path = args[:images_path]
      @tmp_path = args[:tmp_path]
      @current_user = User.find(args[:current_user_id])

      publish_status("running", message: "Starting import…")

      rows = parse_csv
      return if rows.nil?

      validator = ::DiscourseCsvBulkImport::RowValidator.new(rows)
      unless validator.valid?
        publish_status("failed",
          message: "Validation failed with #{validator.validate!.length} error(s)",
          errors: validator.validate!,
        )
        return
      end

      publish_status("running", message: "Validation passed. Importing…")

      results = { total: rows.length, imported: 0, failed: 0, errors: [] }

      grouped = rows.group_by { |r| r["topic_external_id"] }

      grouped.each_with_index do |(external_id, topic_rows), index|
        begin
          ::DiscourseCsvBulkImport::Importer.new(
            topic_rows: topic_rows,
            images_path: @images_path,
            current_user: @current_user,
          ).import!

          results[:imported] += topic_rows.length
        rescue => e
          results[:failed] += topic_rows.length
          results[:errors] << {
            topic_external_id: external_id,
            error: e.message,
          }
        end

        if (index + 1) % BATCH_SIZE == 0 || index == grouped.length - 1
          publish_status("running",
            message: "Processed #{index + 1}/#{grouped.length} topics…",
            progress: results,
          )
        end
      end

      publish_status("complete",
        message: "Import finished. #{results[:imported]} rows imported, #{results[:failed]} failed.",
        progress: results,
      )
    ensure
      FileUtils.rm_rf(@tmp_path) if @tmp_path.present?
    end

    private

    def parse_csv
      require "csv"
      rows = CSV.read(@csv_path, headers: true, liberal_parsing: true).map(&:to_h)

      if rows.empty?
        publish_status("failed", message: "CSV file is empty")
        return nil
      end

      rows
    rescue CSV::MalformedCSVError => e
      publish_status("failed", message: "Malformed CSV: #{e.message}")
      nil
    end

    def publish_status(status, message: nil, progress: nil, errors: nil)
      data = {
        status: status,
        message: message,
        progress: progress,
        errors: errors,
        updated_at: Time.zone.now,
      }

      PluginStore.set(
        ::DiscourseCsvBulkImport::PLUGIN_NAME,
        "import_status_#{@job_id}",
        data,
      )

      MessageBus.publish(
        "/csv-bulk-import/status/#{@job_id}",
        data,
        user_ids: [@current_user.id],
      )
    end
  end
end
