# frozen_string_literal: true

module ::DiscourseCsvBulkImport
  class Importer
    STORE_PREFIX = "imported_topic_"

    def initialize(topic_rows:, images_path:, current_user:)
      @topic_rows = topic_rows.sort_by { |r| r["post_number"].to_i }
      @images_path = images_path
      @current_user = current_user
    end

    def self.already_imported?(external_id)
      PluginStore.get(PLUGIN_NAME, "#{STORE_PREFIX}#{external_id}").present?
    end

    def import!
      external_id = @topic_rows.first["topic_external_id"]

      if self.class.already_imported?(external_id)
        Rails.logger.info("[CsvBulkImport] Skipping already imported topic '#{external_id}'")
        return :skipped
      end

      ActiveRecord::Base.transaction do
        first_row = @topic_rows.first

        validate_chronological_order!

        user = UserResolver.resolve(
          username: first_row["username"],
          email: first_row["email"],
        )

        topic = TopicCreator.create!(
          title: first_row["topic_title"],
          category: first_row["category"],
          tags: parse_tags(first_row["tags"]),
          user: user,
          created_at: first_row["created_at"],
          raw: first_row["content"],
          images_path: @images_path,
        )

        first_post = topic.first_post

        RatingHandler.apply(post: first_post, rating: first_row["rating"]) if first_row["rating"].present?

        Rails.logger.info(
          "[CsvBulkImport] Topic '#{first_row['topic_title']}' created by admin '#{@current_user.username}' " \
          "(topic_external_id: #{external_id})"
        )

        @topic_rows[1..].each do |row|
          log_ignored_fields(row, first_row)

          reply_user = UserResolver.resolve(
            username: row["username"],
            email: row["email"],
          )

          post = TopicCreator.create_reply!(
            topic: topic,
            user: reply_user,
            raw: row["content"],
            created_at: row["created_at"],
            images_path: @images_path,
          )

          RatingHandler.apply(post: post, rating: row["rating"]) if row["rating"].present?
        end

        RatingHandler.update_topic_average(first_post)

        # Mark as imported after successful transaction
        PluginStore.set(PLUGIN_NAME, "#{STORE_PREFIX}#{external_id}", {
          topic_id: topic.id,
          imported_at: Time.zone.now,
          imported_by: @current_user.username,
        })
      end

      :imported
    end

    private

    def parse_tags(tags_string)
      return [] if tags_string.blank?
      tags_string.split(",").map(&:strip)
    end

    def validate_chronological_order!
      timestamps = @topic_rows.map { |r| Time.zone.parse(r["created_at"]) }

      timestamps.each_cons(2).with_index do |(earlier, later), index|
        if later < earlier
          raise "[CsvBulkImport] Post #{@topic_rows[index + 1]['post_number']} has " \
                "created_at (#{later}) before post #{@topic_rows[index]['post_number']} (#{earlier})"
        end
      end
    end

    def log_ignored_fields(reply_row, first_row)
      if reply_row["category"].present? && reply_row["category"] != first_row["category"]
        Rails.logger.warn(
          "[CsvBulkImport] Reply post_number #{reply_row['post_number']}: " \
          "'category' value ignored — only first post's category is used"
        )
      end

      if reply_row["tags"].present?
        Rails.logger.warn(
          "[CsvBulkImport] Reply post_number #{reply_row['post_number']}: " \
          "'tags' value ignored — only first post's tags are used"
        )
      end
    end
  end
end
