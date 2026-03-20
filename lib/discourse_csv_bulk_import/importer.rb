# frozen_string_literal: true

module ::DiscourseCsvBulkImport
  class Importer
    def initialize(topic_rows:, images_path:, current_user:)
      @topic_rows = topic_rows.sort_by { |r| r["post_number"].to_i }
      @images_path = images_path
      @current_user = current_user
    end

    def import!
      ActiveRecord::Base.transaction do
        first_row = @topic_rows.first

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

        @topic_rows[1..].each do |row|
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
      end
    end

    private

    def parse_tags(tags_string)
      return [] if tags_string.blank?
      tags_string.split(",").map(&:strip)
    end
  end
end
