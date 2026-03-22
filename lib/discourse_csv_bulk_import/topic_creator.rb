# frozen_string_literal: true

module ::DiscourseCsvBulkImport
  class TopicCreator
    def self.create!(title:, category:, tags:, user:, created_at:, raw:, images_path:)
      category_id = resolve_category(category)
      processed_raw = MediaHandler.process(raw: raw, images_path: images_path, user: user)

      if tags.present? && !SiteSetting.tagging_enabled
        Rails.logger.warn(
          "[CsvBulkImport] Tags provided but tagging is disabled — tags will be ignored",
        )
      end

      post_creator =
        PostCreator.new(
          user,
          title: title,
          raw: processed_raw,
          category: category_id,
          created_at: Time.zone.parse(created_at),
          skip_validations: true,
          skip_jobs: true,
          skip_guardian: true,
        )

      post = post_creator.create
      unless post.present? && post.errors.blank?
        raise "Failed to create topic '#{title}': #{post&.errors&.full_messages&.join(", ") || "unknown error"}"
      end

      if tags.present? && SiteSetting.tagging_enabled
        DiscourseTagging.tag_topic_by_names(post.topic, Guardian.new(user), tags)
      end

      post.rebake!
      SearchIndexer.index(post)
      post.topic
    end

    def self.create_reply!(topic:, user:, raw:, created_at:, images_path:)
      processed_raw = MediaHandler.process(raw: raw, images_path: images_path, user: user)

      post_creator =
        PostCreator.new(
          user,
          topic_id: topic.id,
          raw: processed_raw,
          created_at: Time.zone.parse(created_at),
          skip_validations: true,
          skip_jobs: true,
          skip_guardian: true,
        )

      post = post_creator.create
      unless post.present? && post.errors.blank?
        raise "Failed to create reply in topic '#{topic.title}': #{post&.errors&.full_messages&.join(", ") || "unknown error"}"
      end

      post.rebake!
      SearchIndexer.index(post)
      post
    end

    private

    def self.resolve_category(category_name)
      return nil if category_name.blank?

      cat =
        Category.find_by(
          "LOWER(name) = ? AND parent_category_id IS NULL",
          category_name.strip.downcase,
        )
      raise "Category '#{category_name}' not found" if cat.nil?

      cat.id
    end
  end
end
