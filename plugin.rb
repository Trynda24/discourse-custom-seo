# frozen_string_literal: true
# name: discourse-custom-seo
# about: Customize meta tags for SEO
# version: 0.1
# authors: YesWeCan
# url: https://github.com/Trynda24/discourse-custom-seo

# Remove this line as meta_tags doesn't exist
# require_dependency 'meta_tags'

enabled_site_setting :custom_seo_enabled

after_initialize do
  Topic.register_custom_field_type('custom_meta_title', :string)
  Topic.register_custom_field_type('custom_meta_description', :string)
  Topic.register_custom_field_type('custom_meta_keywords', :string)
  
  add_to_serializer(:topic_view, :custom_meta_title) { object.topic.custom_fields['custom_meta_title'] }
  add_to_serializer(:topic_view, :custom_meta_description) { object.topic.custom_fields['custom_meta_description'] }
  add_to_serializer(:topic_view, :custom_meta_keywords) { object.topic.custom_fields['custom_meta_keywords'] }
  
  DiscourseEvent.on(:topic_view_headers) do |topic_view, headers|
    if SiteSetting.custom_seo_enabled && topic_view.topic.present?
      topic = topic_view.topic
      
      if topic.custom_fields['custom_meta_title'].present?
        headers[:title] = topic.custom_fields['custom_meta_title']
      end
      
      if topic.custom_fields['custom_meta_description'].present?
        headers[:description] = topic.custom_fields['custom_meta_description'] 
      end
      
      if topic.custom_fields['custom_meta_keywords'].present?
        headers[:keywords] = topic.custom_fields['custom_meta_keywords']
      end
    end
  end
end
