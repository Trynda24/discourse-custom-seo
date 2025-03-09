# frozen_string_literal: true
# name: discourse-custom-seo
# about: Customize meta tags for SEO
# version: 0.3
# authors: YesWeCan
# url: https://github.com/Trynda24/discourse-custom-seo

enabled_site_setting :custom_seo_enabled

after_initialize do
  # Register custom fields for topics
  Topic.register_custom_field_type('custom_meta_title', :string)
  Topic.register_custom_field_type('custom_meta_description', :string)
  Topic.register_custom_field_type('custom_meta_keywords', :string)
  
  # Add custom fields to serializer (this won't affect page rendering)
  add_to_serializer(:topic_view, :custom_meta_title) { object.topic.custom_fields['custom_meta_title'] }
  add_to_serializer(:topic_view, :custom_meta_description) { object.topic.custom_fields['custom_meta_description'] }
  add_to_serializer(:topic_view, :custom_meta_keywords) { object.topic.custom_fields['custom_meta_keywords'] }
  
  # Simple hook to modify metadata without breaking page rendering
  DiscourseEvent.on(:topic_view_metadata) do |topic_view, metadata|
    if SiteSetting.custom_seo_enabled && topic_view.topic.present?
      topic = topic_view.topic
      
      if topic.custom_fields['custom_meta_title'].present?
        metadata[:title] = topic.custom_fields['custom_meta_title']
      end
      
      if topic.custom_fields['custom_meta_description'].present?
        metadata[:description] = topic.custom_fields['custom_meta_description'] 
      end
      
      if topic.custom_fields['custom_meta_keywords'].present?
        metadata[:keywords] = topic.custom_fields['custom_meta_keywords']
      end
    end
  end
  
  # Add meta tags via a simpler method that won't interfere with rendering
  register_html_builder('server:before-head-close') do |controller|
    result = ""
    if controller.instance_variable_defined?(:@topic) && 
       controller.instance_variable_get(:@topic) && 
       SiteSetting.custom_seo_enabled
       
      topic = controller.instance_variable_get(:@topic)
      
      if topic.custom_fields['custom_meta_title'].present?
        result += "<meta property='og:title' content='#{ERB::Util.html_escape(topic.custom_fields['custom_meta_title'])}'>"
      end
      
      if topic.custom_fields['custom_meta_description'].present?
        result += "<meta name='description' content='#{ERB::Util.html_escape(topic.custom_fields['custom_meta_description'])}'>"
        result += "<meta property='og:description' content='#{ERB::Util.html_escape(topic.custom_fields['custom_meta_description'])}'>"
      end
      
      if topic.custom_fields['custom_meta_keywords'].present?
        result += "<meta name='keywords' content='#{ERB::Util.html_escape(topic.custom_fields['custom_meta_keywords'])}'>"
      end
    end
    
    result
  end
  
  # Add route to update custom fields via API - keep this part
  Discourse::Application.routes.append do
    put "topics/:id/custom_seo" => "topics#update_custom_seo", constraints: { id: /\d+/ }
  end
  
  # Add controller method for updating custom SEO fields - keep this part
  add_to_class :topics_controller, :update_custom_seo do
    topic = Topic.find_by(id: params[:id])
    guardian.ensure_can_edit!(topic)
    
    if topic.present? && params[:custom_fields].present?
      custom_fields = params[:custom_fields]
      
      # Update custom fields
      if custom_fields[:custom_meta_title].present?
        topic.custom_fields['custom_meta_title'] = custom_fields[:custom_meta_title]
      end
      
      if custom_fields[:custom_meta_description].present?
        topic.custom_fields['custom_meta_description'] = custom_fields[:custom_meta_description]
      end
      
      if custom_fields[:custom_meta_keywords].present?
        topic.custom_fields['custom_meta_keywords'] = custom_fields[:custom_meta_keywords]
      end
      
      topic.save_custom_fields
      render json: success_json
    else
      render json: failed_json.merge(errors: [I18n.t('not_found')]), status: 404
    end
  end
end
