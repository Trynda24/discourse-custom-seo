# frozen_string_literal: true

# name: discourse-custom-seo
# about: Customize meta tags for SEO
# version: 0.1
# authors: YesWeCan
# url: https://github.com/Trynda24/discourse-custom-seo

require_dependency 'meta_tags'

enabled_site_setting :custom_seo_enabled

after_initialize do
  Topic.register_custom_field_type('custom_meta_title', :string)
  Topic.register_custom_field_type('custom_meta_description', :string)
  Topic.register_custom_field_type('custom_meta_keywords', :string)

  add_to_serializer(:topic_view, :custom_meta_title) { object.custom_fields['custom_meta_title'] }
  add_to_serializer(:topic_view, :custom_meta_description) { object.custom_fields['custom_meta_description'] }
  add_to_serializer(:topic_view, :custom_meta_keywords) { object.custom_fields['custom_meta_keywords'] }

  DiscourseEvent.on(:header_tags) do |controller, _context|
    if SiteSetting.custom_seo_enabled
      topic = controller.instance_variable_get(:@topic)
      meta_title = topic.custom_fields['custom_meta_title']
      meta_description = topic.custom_fields['custom_meta_description']
      meta_keywords = topic.custom_fields['custom_meta_keywords']

      if meta_title.present?
        controller.instance_variable_set(:@title, meta_title)
      end

      if meta_description.present?
        controller.instance_variable_set(:@meta_description, meta_description)
      end

      if meta_keywords.present?
        controller.instance_variable_set(:@meta_keywords, meta_keywords)
      end
    end
  end
end
