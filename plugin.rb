# name: discourse-custom-seo
# about: Customize meta tags for SEO
# version: 0.1
# authors: YesWeCan
# url: https://github.com/Trynda24/discourse-custom-seo

enabled_site_setting :custom_seo_enabled

after_initialize do
  # Register custom topic fields
  Topic.register_custom_field_type('custom_meta_title', :string)
  Topic.register_custom_field_type('custom_meta_description', :string)
  Topic.register_custom_field_type('custom_meta_keywords', :string)
  
  # Add fields to topic view serializer
  add_to_serializer(:topic_view, :custom_meta_title) do
    object.topic.custom_fields['custom_meta_title']
  end
  
  add_to_serializer(:topic_view, :custom_meta_description) do
    object.topic.custom_fields['custom_meta_description']
  end
  
  add_to_serializer(:topic_view, :custom_meta_keywords) do
    object.topic.custom_fields['custom_meta_keywords']
  end

  # Make these fields available when loading topics
  TopicView.default_post_custom_fields << "custom_meta_title"
  TopicView.default_post_custom_fields << "custom_meta_description"
  TopicView.default_post_custom_fields << "custom_meta_keywords"

  # Set up the controller for API endpoints
  add_api_endpoint "/discourse-custom-seo/update-meta" do |request|
    topic_id = request.params[:topic_id]
    topic = Topic.find_by(id: topic_id)
    
    if !topic
      { error: "Topic not found" }
    elsif !guardian.can_edit?(topic)
      { error: "You don't have permission to edit this topic" }
    else
      # Update the custom fields
      topic.custom_fields['custom_meta_title'] = request.params[:custom_title]
      topic.custom_fields['custom_meta_description'] = request.params[:custom_description]
      topic.custom_fields['custom_meta_keywords'] = request.params[:custom_keywords]
      topic.save_custom_fields(true)
      
      { success: true }
    end
  end
  
  # Override the application helper to use custom meta data
  ApplicationHelper.module_eval do
    def crawlable_meta_data(opts = nil)
      opts ||= {}
      
      if @topic_view&.topic
        topic = @topic_view.topic
        opts[:title] = topic.custom_fields["custom_meta_title"].presence || opts[:title]
        opts[:description] = topic.custom_fields["custom_meta_description"].presence || opts[:description]
        opts[:keywords] = topic.custom_fields["custom_meta_keywords"].presence || opts[:keywords]
      end
      
      super(opts)
    end
  end
end
