# frozen_string_literal: true
# name: discourse-custom-seo
# about: Customize meta tags for SEO
# version: 0.2
# authors: YesWeCan
# url: https://github.com/Trynda24/discourse-custom-seo

enabled_site_setting :custom_seo_enabled

after_initialize do
  # Register custom fields for topics
  Topic.register_custom_field_type('custom_meta_title', :string)
  Topic.register_custom_field_type('custom_meta_description', :string)
  Topic.register_custom_field_type('custom_meta_keywords', :string)
  
  # Add custom fields to serializer
  add_to_serializer(:topic_view, :custom_meta_title) { object.topic.custom_fields['custom_meta_title'] }
  add_to_serializer(:topic_view, :custom_meta_description) { object.topic.custom_fields['custom_meta_description'] }
  add_to_serializer(:topic_view, :custom_meta_keywords) { object.topic.custom_fields['custom_meta_keywords'] }
  
  # Override the default meta tag data if custom fields are present
  reloadable_patch do
    ApplicationController.class_eval do
      def set_topic_and_user_in_cookies
        super
        
        # Only modify title/metadata for topic pages
        if @topic && SiteSetting.custom_seo_enabled
          if @topic.custom_fields['custom_meta_title'].present?
            @title = @topic.custom_fields['custom_meta_title']
          end
          
          if @topic.custom_fields['custom_meta_description'].present?
            @description = @topic.custom_fields['custom_meta_description']
          end
        end
      end
    end
    
    # Override the HTML metadata
    TopicView.class_eval do
      def canonical_path
        path = super
        if SiteSetting.custom_seo_enabled && @topic.custom_fields['custom_meta_title'].present?
          @canonical_url = path
        end
        path
      end
    end
  end
  
  # Override metadata in HTML head
  on(:topic_view_metadata) do |topic_view, metadata|
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
  
  # Add custom meta tags directly to HTML head
  plugin_name = :custom_seo
  register_html_builder(plugin_name) do |controller|
    if controller.instance_variable_defined?(:@topic) && 
       controller.instance_variable_get(:@topic) && 
       SiteSetting.custom_seo_enabled
       
      topic = controller.instance_variable_get(:@topic)
      result = ""
      
      if topic.custom_fields['custom_meta_title'].present?
        # Override the default title tag completely
        result += "<title>#{ERB::Util.html_escape(topic.custom_fields['custom_meta_title'])}</title>"
      end
      
      if topic.custom_fields['custom_meta_description'].present?
        # Remove default description and add our custom one
        result += "<meta name='description' content='#{ERB::Util.html_escape(topic.custom_fields['custom_meta_description'])}'>"
      end
      
      if topic.custom_fields['custom_meta_keywords'].present?
        result += "<meta name='keywords' content='#{ERB::Util.html_escape(topic.custom_fields['custom_meta_keywords'])}'>"
      end
      
      result
    else
      ""
    end
  end
  
  # Add route to update custom fields via API
  Discourse::Application.routes.append do
    put "topics/:id/custom_seo" => "topics#update_custom_seo", constraints: { id: /\d+/ }
  end
  
  # Add controller method for updating custom SEO fields
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
  
  # Make sure we fully remove default meta tags
  on(:before_discourse_html_meta_tags) do |tags|
    controller = tags.controller
    if controller.instance_variable_defined?(:@topic) && 
       controller.instance_variable_get(:@topic) && 
       SiteSetting.custom_seo_enabled
       
      topic = controller.instance_variable_get(:@topic)
      
      if topic.custom_fields['custom_meta_title'].present?
        # Remove default title tags
        tags.delete_if { |tag| tag[:name] == :title }
      end
      
      if topic.custom_fields['custom_meta_description'].present?
        # Remove default description tags
        tags.delete_if { |tag| tag[:name] == :description }
      end
    end
  end
end
