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

  # Override Discourse's automatic meta data
  Discourse::Application.routes do
    concern :auto_completable do
      post :complete
    end

    resources :topics do
      concern :auto_completable
    end
  end

  # Add meta tags to the topic view
  hook_listener(:header_tags) do
    if SiteSetting.custom_seo_enabled
      topic = @topic
      meta_title = topic.custom_fields['custom_meta_title']
      meta_description = topic.custom_fields['custom_meta_description']
      meta_keywords = topic.custom_fields['custom_meta_keywords']

      # Override Discourse's automatic meta title
      if meta_title.present?
        @title = meta_title
      end

      # Override Discourse's automatic meta description
      if meta_description.present?
        meta_tags += [MetaTag.tag(:name => 'description', :content => meta_description)]
      end

      # Add meta keywords tag
      if meta_keywords.present?
        meta_tags += [MetaTag.tag(:name => 'keywords', :content => meta_keywords)]
      end
    end
  end
end
