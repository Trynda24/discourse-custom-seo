# name: discourse-custom-seo
# about: Customize meta tags for SEO
# version: 0.1
# authors: YesWeCan
# url: https://github.com/Trynda24/discourse-custom-seo

enabled_site_setting :custom_seo_enabled

after_initialize do
  # Register custom fields for topics
  Topic.register_custom_field_type('custom_meta_title', :string)
  Topic.register_custom_field_type('custom_meta_description', :string)
  Topic.register_custom_field_type('custom_meta_keywords', :string)

  # Make the fields accessible to ALL users (including anonymous users)
  add_to_serializer(:topic_view, :custom_meta_title, include_condition: -> { true }) do
    object.topic.custom_fields['custom_meta_title']
  end

  add_to_serializer(:topic_view, :custom_meta_description, include_condition: -> { true }) do
    object.topic.custom_fields['custom_meta_description']
  end

  add_to_serializer(:topic_view, :custom_meta_keywords, include_condition: -> { true }) do
    object.topic.custom_fields['custom_meta_keywords']
  end
end
