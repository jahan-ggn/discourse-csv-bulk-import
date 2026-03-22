# frozen_string_literal: true

module ::DiscourseCsvBulkImport
  class UserResolver
    def self.resolve(username:, email:)
      # Check by email first — most reliable identifier
      user = User.find_by_email(email)
      if user.present?
        if user.username.downcase != username.downcase
          Rails.logger.warn(
            "[CsvBulkImport] CSV username '#{username}' doesn't match existing user '#{user.username}' " \
            "for email '#{email}' — using existing user"
          )
        end
        return user
      end

      # Check by username
      user = User.find_by_username(username)
      if user.present?
        Rails.logger.warn(
          "[CsvBulkImport] Username '#{username}' exists but with a different email. " \
          "Matched by email failed. Creating new user with modified username."
        )
      end

      create_user(username: username, email: email)
    end

    private

    def self.create_user(username:, email:)
      suggested = UserNameSuggester.find_available_username_based_on(username)

      if suggested != username
        Rails.logger.warn(
          "[CsvBulkImport] Username '#{username}' was not available. " \
          "Created user with username '#{suggested}' instead."
        )
      end

      user = User.new(
        username: suggested,
        email: email,
        active: true,
        approved: true,
        trust_level: SiteSetting.default_trust_level,
      )

      user.save!(validate: false)

      Rails.logger.info("[CsvBulkImport] Created new user '#{suggested}' (#{email})")

      user
    end
  end
end
