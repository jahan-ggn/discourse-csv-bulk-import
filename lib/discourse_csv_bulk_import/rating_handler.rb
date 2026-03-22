# frozen_string_literal: true

module ::DiscourseCsvBulkImport
  class RatingHandler
    def self.apply(post:, rating:)
      return if rating.blank?

      unless defined?(DiscourseRatings)
        Rails.logger.warn(
          "[CsvBulkImport] Rating value provided but discourse-ratings plugin is not installed — skipping",
        )
        return
      end

      value = rating.to_f
      return if value < 1 || value > 5

      types = post.topic.rating_types
      if types.blank?
        Rails.logger.warn(
          "[CsvBulkImport] No rating types configured for topic '#{post.topic.title}' — skipping rating",
        )
        return
      end

      types.each do |type|
        DiscourseRatings::Rating.build_and_set(post, { type: type, value: value, weight: 1 })
      end

      post.save_custom_fields(true)
    end

    def self.update_topic_average(post)
      return unless defined?(DiscourseRatings)

      post.update_topic_ratings
    end
  end
end
