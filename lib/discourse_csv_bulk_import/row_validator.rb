# frozen_string_literal: true

module ::DiscourseCsvBulkImport
  class RowValidator
    REQUIRED_COLUMNS = %w[
      topic_external_id
      topic_title
      username
      email
      created_at
      post_number
      content
    ].freeze

    MAX_ROW_COUNT = 10_000

    def initialize(rows)
      @rows = rows
      @errors = []
      @validated = false
    end

    def validate!
      return @errors if @validated
      @validated = true

      validate_row_count
      return @errors if @errors.any?

      validate_columns
      return @errors if @errors.any?

      @rows.each_with_index do |row, index|
        line = index + 2

        validate_required_fields(row, line)
        validate_post_number(row, line)
        validate_created_at(row, line)
        validate_email(row, line)
        validate_rating(row, line)
        validate_username(row, line)
        validate_content_length(row, line)
        validate_topic_external_id(row, line)
      end

      validate_topic_integrity if @errors.empty?

      @errors
    end

    def valid?
      validate!
      @errors.empty?
    end

    private

    def validate_row_count
      if @rows.length > MAX_ROW_COUNT
        @errors << "CSV has #{@rows.length} rows — maximum allowed is #{MAX_ROW_COUNT}"
      end
    end

    def first_post?(row)
      row["post_number"].to_i == 1
    end

    def validate_required_fields(row, line)
      REQUIRED_COLUMNS.each do |col|
        if first_post?(row) && row[col].to_s.strip.blank?
          @errors << "Row #{line}: '#{col}' is required"
        elsif !first_post?(row) && %w[username email created_at post_number content].include?(col) && row[col].to_s.strip.blank?
          @errors << "Row #{line}: '#{col}' is required"
        end
      end
    end

    def validate_columns
      first_keys = @rows.first&.keys || []
      missing = REQUIRED_COLUMNS - first_keys
      if missing.any?
        @errors << "Missing columns: #{missing.join(', ')}"
      end

      @rows.each_with_index do |row, index|
        row_missing = REQUIRED_COLUMNS - row.keys
        if row_missing.any?
          @errors << "Row #{index + 2}: missing columns: #{row_missing.join(', ')}"
        end
      end
    end

    def validate_post_number(row, line)
      val = row["post_number"].to_i
      if val < 1
        @errors << "Row #{line}: 'post_number' must be >= 1"
      end
    end

    def validate_created_at(row, line)
      result = Time.zone.parse(row["created_at"])
      if result.nil?
        @errors << "Row #{line}: 'created_at' is not a valid datetime"
      end
    rescue ArgumentError, TypeError
      @errors << "Row #{line}: 'created_at' is not a valid datetime"
    end

    def validate_email(row, line)
      unless row["email"].to_s.match?(/\A[^@\s]+@[^@\s]+\.[^@\s]+\z/)
        @errors << "Row #{line}: 'email' is not valid"
      end
    end

    def validate_rating(row, line)
      return if row["rating"].blank?

      unless row["rating"].to_s.match?(/\A\d+(\.\d+)?\z/)
        @errors << "Row #{line}: 'rating' is not a valid number"
        return
      end

      val = row["rating"].to_f
      if val < 1 || val > 5
        @errors << "Row #{line}: 'rating' must be between 1 and 5"
      end
    end

    def validate_username(row, line)
      username = row["username"].to_s.strip
      return if username.blank?

      unless username.match?(/\A[a-zA-Z0-9_.-]+\z/)
        @errors << "Row #{line}: 'username' contains invalid characters"
      end

      if username.length < 2 || username.length > 60
        @errors << "Row #{line}: 'username' must be between 2 and 60 characters"
      end
    end

    def validate_content_length(row, line)
      content = row["content"].to_s
      return if content.blank?

      max = defined?(SiteSetting) ? SiteSetting.max_post_length : 32_000
      if content.length > max
        @errors << "Row #{line}: 'content' exceeds maximum length of #{max} characters"
      end
    end

    def validate_topic_external_id(row, line)
      if row["topic_external_id"].to_s.strip.blank?
        @errors << "Row #{line}: 'topic_external_id' cannot be blank"
      end
    end

    def validate_topic_integrity
      grouped = @rows.group_by { |r| r["topic_external_id"] }

      grouped.each do |external_id, topic_rows|
        first_posts = topic_rows.select { |r| r["post_number"].to_i == 1 }

        if first_posts.empty?
          @errors << "Topic '#{external_id}': missing post_number 1"
        elsif first_posts.length > 1
          @errors << "Topic '#{external_id}': duplicate post_number 1"
        end

        first = first_posts.first
        if first && first["topic_title"].to_s.strip.blank?
          @errors << "Topic '#{external_id}': 'topic_title' required on first post"
        end

        numbers = topic_rows.map { |r| r["post_number"].to_i }
        if numbers.uniq.length != numbers.length
          @errors << "Topic '#{external_id}': duplicate post numbers found"
        end
      end
    end
  end
end
