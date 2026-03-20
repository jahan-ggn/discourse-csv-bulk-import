# frozen_string_literal: true

module ::DiscourseCsvBulkImport
  class UserResolver
    def self.resolve(username:, email:)
        user = User.find_by_username(username)
        if user.present?
            return user if user.email.downcase == email.downcase
            # Username taken by different person — check email
        end

        user = User.find_by_email(email)
        return user if user.present?

        create_user(username: username, email: email)
    end

    private

    def self.create_user(username:, email:)
      password = SecureRandom.hex(16)

      user = User.new(
        username: UserNameSuggester.find_available_username_based_on(username),
        email: email,
        password: password,
        active: true,
        approved: true,
        trust_level: SiteSetting.default_trust_level,
      )

      user.save!(validate: false)
      user
    end
  end
end
