# frozen_string_literal: true

module ::DiscourseCsvBulkImport
  class RatingHandler
    def self.apply(post:, rating:)
      return if rating.blank?

      value = rating.to_f
      return if value <= 0 || value > 5

      types = post.topic.rating_types
      return if types.blank?

      types.each do |type|
        DiscourseRatings::Rating.build_and_set(
          post,
          { type: type, value: value, weight: 1 },
        )
      end

      post.save_custom_fields(true)
    end

    def self.update_topic_average(post)
      post.update_topic_ratings
    end
  end
end
