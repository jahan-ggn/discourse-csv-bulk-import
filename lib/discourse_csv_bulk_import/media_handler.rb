# frozen_string_literal: true

module ::DiscourseCsvBulkImport
  class MediaHandler
    IMAGE_REGEX = /!\[([^\]]*)\]\((?:uploads\/import_media\/)?([^)]+)\)/

    def self.process(raw:, images_path:)
      return raw if raw.blank? || images_path.blank?

      raw.gsub(IMAGE_REGEX) do |match|
        alt_text = $1
        filename = $2
        file_path = File.join(images_path, filename)

        if File.exist?(file_path)
          upload = create_upload(file_path, filename)
          if upload&.persisted?
            "![#{alt_text}](#{upload.short_url})"
          else
            Rails.logger.warn("[CsvBulkImport] Failed to upload image: #{filename}")
            match
          end
        else
          Rails.logger.warn("[CsvBulkImport] Image not found: #{file_path}")
          match
        end
      end
    end

    private

    def self.create_upload(file_path, filename)
      tmp = File.open(file_path)

      UploadCreator.new(
        tmp,
        filename,
        skip_validations: true,
      ).create_for(Discourse.system_user.id)
    ensure
      tmp&.close
    end
  end
end
