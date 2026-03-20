# frozen_string_literal: true

module ::DiscourseCsvBulkImport
  class ImportController < ::Admin::AdminController
    requires_plugin PLUGIN_NAME

    MAX_ZIP_SIZE = 100.megabytes

    def create
      file = params.require(:file)

      validate_upload!(file)

      tmp_path = setup_tmp_dir
      extract_zip(file, tmp_path)

      csv_path = find_csv!(tmp_path)
      images_path = File.join(tmp_path, "import_media")
      FileUtils.mkdir_p(images_path)

      job_id = SecureRandom.hex(16)

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
      render json: data || { status: "pending" }
    end

    private

    def validate_upload!(file)
      unless file.original_filename.match?(/\.zip$/i)
        raise Discourse::InvalidParameters.new("File must be a .zip archive")
      end

      if file.size > MAX_ZIP_SIZE
        raise Discourse::InvalidParameters.new("File exceeds maximum size of #{MAX_ZIP_SIZE / 1.megabyte}MB")
      end
    end

    def setup_tmp_dir
      path = File.join(Rails.root, "tmp", "csv_import_#{SecureRandom.hex(8)}")
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
        raise Discourse::InvalidParameters.new("No CSV file found inside the zip")
      end

      if csv_files.length > 1
        FileUtils.rm_rf(tmp_path)
        raise Discourse::InvalidParameters.new("Multiple CSV files found — zip must contain exactly one")
      end

      csv_files.first
    end
  end
end
