# frozen_string_literal: true

module ::DiscourseCsvBulkImport
  class TopicCreator
    def self.create!(title:, category:, tags:, user:, created_at:, raw:, images_path:)
      category_id = resolve_category(category)
      processed_raw = MediaHandler.process(raw: raw, images_path: images_path)

      post_creator = PostCreator.new(
        user,
        title: title,
        raw: processed_raw,
        category: category_id,
        tags: tags,
        created_at: Time.zone.parse(created_at),
        skip_validations: true,
        skip_jobs: true,
        skip_guardian: true,
      )

      post = post_creator.create!
      post.topic
    end

    def self.create_reply!(topic:, user:, raw:, created_at:, images_path:)
      processed_raw = MediaHandler.process(raw: raw, images_path: images_path)

      post_creator = PostCreator.new(
        user,
        topic_id: topic.id,
        raw: processed_raw,
        created_at: Time.zone.parse(created_at),
        skip_validations: true,
        skip_jobs: true,
        skip_guardian: true,
      )

      post_creator.create!
    end

    private

    def self.resolve_category(category_name)
      return nil if category_name.blank?

      cat = Category.find_by("LOWER(name) = ?", category_name.strip.downcase)
      raise "Category '#{category_name}' not found" if cat.nil?

      cat.id
    end
  end
end
