# frozen_string_literal: true

module ::DiscourseCsvBulkImport
  class ImportController < ::Admin::AdminController
    requires_plugin PLUGIN_NAME

    MAX_ZIP_SIZE = 100.megabytes

    def create
      unless SiteSetting.discourse_csv_bulk_import_enabled
        raise Discourse::InvalidAccess.new(
                I18n.t("discourse_csv_bulk_import.errors.plugin_disabled"),
              )
      end

      file = params.require(:file)

      validate_upload!(file)

      tmp_path = setup_tmp_dir
      extract_zip(file, tmp_path)

      csv_path = find_csv!(tmp_path)
      images_path = File.dirname(csv_path)

      job_id = SecureRandom.hex(16)

      PluginStore.set(
        PLUGIN_NAME,
        "import_status_#{job_id}",
        { status: "queued", message: "Import queued…", updated_at: Time.zone.now },
      )

      Jobs.enqueue(
        :run_csv_import,
        job_id: job_id,
        csv_path: csv_path,
        images_path: images_path,
        tmp_path: tmp_path,
        current_user_id: current_user.id,
      )

      render json: { job_id: job_id }
    end

    def status
      job_id = params.require(:job_id)
      data = PluginStore.get(PLUGIN_NAME, "import_status_#{job_id}")
      render json: data || { status: "unknown" }
    end

    def active
      rows =
        PluginStoreRow.where(plugin_name: ::DiscourseCsvBulkImport::PLUGIN_NAME).where(
          "key LIKE 'import_status_%'",
        )

      active_job = nil

      rows.find_each do |row|
        data =
          begin
            JSON.parse(row.value)
          rescue StandardError
            next
          end
        next if data["user_id"] != current_user.id

        if !%w[complete failed].include?(data["status"]) && data["updated_at"].present? &&
             Time.zone.parse(data["updated_at"]) < 1.minute.ago
          next
        end

        if %w[complete failed].include?(data["status"]) && data["updated_at"].present? &&
             Time.zone.parse(data["updated_at"]) < 1.hour.ago
          next
        end

        active_job = data if active_job.nil? || data["updated_at"] > active_job["updated_at"]
      end

      render json: active_job || { status: "none" }
    end

    private

    def validate_upload!(file)
      unless file.original_filename.match?(/\.zip$/i)
        raise Discourse::InvalidParameters.new(
                I18n.t("discourse_csv_bulk_import.errors.file_not_zip"),
              )
      end

      if file.size > MAX_ZIP_SIZE
        raise Discourse::InvalidParameters.new(
                I18n.t(
                  "discourse_csv_bulk_import.errors.file_too_large",
                  max_size: MAX_ZIP_SIZE / 1.megabyte,
                ),
              )
      end
    end

    def setup_tmp_dir
      path = File.join(Dir.tmpdir, "csv_import_#{SecureRandom.hex(8)}")
      FileUtils.mkdir_p(path)
      path
    end

    def extract_zip(file, dest)
      Discourse::Utils.execute_command("unzip", "-o", file.tempfile.path, "-d", dest)
    rescue => e
      FileUtils.rm_rf(dest)
      raise Discourse::InvalidParameters.new("Failed to extract zip: #{e.message}")
    end

    def find_csv!(tmp_path)
      csv_files = Dir.glob(File.join(tmp_path, "**", "*.csv"))

      if csv_files.empty?
        FileUtils.rm_rf(tmp_path)
        raise Discourse::InvalidParameters.new(
                I18n.t("discourse_csv_bulk_import.errors.no_csv_found"),
              )
      end

      if csv_files.length > 1
        FileUtils.rm_rf(tmp_path)
        raise Discourse::InvalidParameters.new(
                I18n.t("discourse_csv_bulk_import.errors.multiple_csv_found"),
              )
      end

      csv_files.first
    end
  end
end
