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

    def initialize(rows)
      @rows = rows
      @errors = []
    end

    def validate!
      validate_columns
      return @errors if @errors.any?

      @rows.each_with_index do |row, index|
        line = index + 2 # +1 for header, +1 for 1-based

        REQUIRED_COLUMNS.each do |col|
          if first_post?(row) && row[col].blank?
            @errors << "Row #{line}: '#{col}' is required"
          elsif !first_post?(row) && %w[username email created_at post_number content].include?(col) && row[col].blank?
            @errors << "Row #{line}: '#{col}' is required"
          end
        end

        validate_post_number(row, line)
        validate_created_at(row, line)
        validate_email(row, line)
        validate_rating(row, line)
      end

      validate_topic_integrity

      @errors
    end

    def valid?
      validate! if @errors.empty?
      @errors.empty?
    end

    private

    def first_post?(row)
      row["post_number"].to_i == 1
    end

    def validate_columns
      missing = REQUIRED_COLUMNS - @rows.first.keys
      if missing.any?
        @errors << "Missing columns: #{missing.join(', ')}"
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
      unless row["email"].to_s.match?(/\A[^@\s]+@[^@\s]+\z/)
        @errors << "Row #{line}: 'email' is not valid"
      end
    end

    def validate_rating(row, line)
      return if row["rating"].blank?

      val = row["rating"].to_f
      if val <= 0 || val > 5
        @errors << "Row #{line}: 'rating' must be between 1 and 5"
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
        if first && first["topic_title"].blank?
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
