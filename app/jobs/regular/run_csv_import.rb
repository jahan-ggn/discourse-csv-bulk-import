# frozen_string_literal: true

module Jobs
  class RunCsvImport < ::Jobs::Base
    sidekiq_options retry: false

    PROGRESS_INTERVAL = 25

    def execute(args)
      @job_id = args[:job_id]
      @csv_path = args[:csv_path]
      @images_path = args[:images_path]
      @tmp_path = args[:tmp_path]
      @current_user_id = args[:current_user_id]

      validate_args!

      @current_user = User.find(@current_user_id)

      publish_status("running", message: "Starting import…")

      rows = parse_csv
      return if rows.nil?

      validator = ::DiscourseCsvBulkImport::RowValidator.new(rows)
      unless validator.valid?
        errors = validator.validate!
        publish_status("failed",
          message: "Validation failed with #{errors.length} error(s)",
          errors: errors,
        )
        return
      end

      publish_status("running", message: "Validation passed. Importing…")

      grouped = rows.group_by { |r| r["topic_external_id"] }
      results = { total_topics: grouped.length, total_rows: rows.length, imported_topics: 0, skipped_topics: 0, failed_topics: 0, errors: [] }

      grouped.each_with_index do |(external_id, topic_rows), index|
        begin
          status = ::DiscourseCsvBulkImport::Importer.new(
            topic_rows: topic_rows,
            images_path: @images_path,
            current_user: @current_user,
          ).import!

          if status == :skipped
            results[:skipped_topics] += 1
          else
            results[:imported_topics] += 1
          end
        rescue => e
          results[:failed_topics] += 1
          results[:errors] << {
            topic_external_id: external_id,
            error: e.message,
          }
          Rails.logger.error("[CsvBulkImport] Failed to import topic '#{external_id}': #{e.message}")
        end

        if (index + 1) % PROGRESS_INTERVAL == 0 || index == grouped.length - 1
          publish_status("running",
            message: "Processed #{index + 1}/#{grouped.length} topics…",
            progress: results,
          )
        end
      end

      publish_status("complete",
        message: "Import finished. #{results[:imported_topics]} imported, #{results[:skipped_topics]} skipped, #{results[:failed_topics]} failed.",
        progress: results,
      )

      Rails.logger.info(
        "[CsvBulkImport] Import #{@job_id} completed by #{@current_user.username}: " \
        "#{results[:imported_topics]} imported, #{results[:skipped_topics]} skipped, #{results[:failed_topics]} failed"
      )
    rescue => e
      publish_status("failed", message: "Unexpected error: #{e.message}")
      Rails.logger.error("[CsvBulkImport] Job #{@job_id} crashed: #{e.class} — #{e.message}")
    ensure
      FileUtils.rm_rf(@tmp_path) if @tmp_path.present?
    end

    private

    def validate_args!
      %i[job_id csv_path images_path current_user_id].each do |key|
        raise "[CsvBulkImport] Missing required job argument: #{key}" if instance_variable_get(:"@#{key}").nil?
      end
    end

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
        user_ids: [@current_user_id],
      )
    end
  end
end
