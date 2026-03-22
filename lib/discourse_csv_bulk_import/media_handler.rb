# frozen_string_literal: true

module ::DiscourseCsvBulkImport
  class MediaHandler
    MEDIA_REGEX = /!\[([^\]]*)\]\(uploads\/([^)]+)\)/

    def self.process(raw:, images_path:, user:)
      return raw if raw.blank? || images_path.blank?

      upload_cache = {}

      raw.gsub(MEDIA_REGEX) do |match|
        alt_text = $1
        filename = URI.decode_www_form_component($2)
        file_path = File.join(images_path, File.basename(filename))

        unless File.exist?(file_path)
          Rails.logger.warn("[CsvBulkImport] Media not found: #{file_path}")
          next match
        end

        upload = upload_cache[filename]
        unless upload
          upload = create_upload(file_path, filename, user)
          upload_cache[filename] = upload if upload&.persisted?
        end

        if upload&.persisted?
          "![#{alt_text}](#{upload.short_url})"
        else
          Rails.logger.warn("[CsvBulkImport] Failed to upload media: #{filename}")
          match
        end
      end
    end

    private

    def self.create_upload(file_path, filename, user)
      tmp = File.open(file_path, "rb")

      UploadCreator.new(
        tmp,
        filename,
      ).create_for(user.id)
    ensure
      tmp&.close
    end
  end
end
