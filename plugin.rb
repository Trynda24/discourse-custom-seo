# frozen_string_literal: true
# name: discourse-custom-seo
# about: Customize meta tags for SEO
# version: 0.4
# authors: YesWeCan
# url: https://github.com/Trynda24/discourse-custom-seo

enabled_site_setting :custom_seo_enabled

after_initialize do
  # Register custom fields for topics
  Topic.register_custom_field_type('custom_meta_title', :string)
  Topic.register_custom_field_type('custom_meta_description', :string)
  Topic.register_custom_field_type('custom_meta_keywords', :string)
  
  # Add custom fields to serializer to make them available in the API
  add_to_serializer(:topic_view, :custom_meta_title) { object.topic.custom_fields['custom_meta_title'] }
  add_to_serializer(:topic_view, :custom_meta_description) { object.topic.custom_fields['custom_meta_description'] }
  add_to_serializer(:topic_view, :custom_meta_keywords) { object.topic.custom_fields['custom_meta_keywords'] }
  
  # Direct HTML modification to ensure meta tags are properly replaced
  on :before_head_close do |controller, html|
    if controller.instance_variable_defined?(:@topic) && 
       controller.instance_variable_get(:@topic) && 
       SiteSetting.custom_seo_enabled
       
      topic = controller.instance_variable_get(:@topic)
      
      if topic.custom_fields['custom_meta_title'].present?
        # Force override the title element itself
        html.gsub!(/<title>.*?<\/title>/, "<title>#{ERB::Util.html_escape(topic.custom_fields['custom_meta_title'])}</title>")
        
        # Override meta tags by removing existing ones and adding new ones
        html.gsub!(/<meta (name|property)=("|')og:title("|') content=("|').*?("|')>/, "")
        html += "<meta property='og:title' content='#{ERB::Util.html_escape(topic.custom_fields['custom_meta_title'])}'>"
      end
      
      if topic.custom_fields['custom_meta_description'].present?
        html.gsub!(/<meta name=("|')description("|') content=("|').*?("|')>/, "")
        html.gsub!(/<meta property=("|')og:description("|') content=("|').*?("|')>/, "")
        html += "<meta name='description' content='#{ERB::Util.html_escape(topic.custom_fields['custom_meta_description'])}'>"
        html += "<meta property='og:description' content='#{ERB::Util.html_escape(topic.custom_fields['custom_meta_description'])}'>"
      end
      
      if topic.custom_fields['custom_meta_keywords'].present?
        html.gsub!(/<meta name=("|')keywords("|') content=("|').*?("|')>/, "")
        html += "<meta name='keywords' content='#{ERB::Util.html_escape(topic.custom_fields['custom_meta_keywords'])}'>"
      end
    end
    
    html
  end
  
  # Fallback approach using the event system
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
      
      # Force clear cache to ensure changes take effect immediately
      topic.clear_attribute_cache!
      
      render json: success_json
    else
      render json: failed_json.merge(errors: [I18n.t('not_found')]), status: 404
    end
  end
  
  # Add JavaScript to ensure the custom meta data is applied even if other methods fail
  register_html_builder('server:before-head-close') do |controller|
    next "" unless SiteSetting.custom_seo_enabled
    next "" unless controller.instance_variable_defined?(:@topic) && controller.instance_variable_get(:@topic)
    
    topic = controller.instance_variable_get(:@topic)
    
    # Only include the script if there are custom fields
    if topic.custom_fields['custom_meta_title'].present? || 
       topic.custom_fields['custom_meta_description'].present? || 
       topic.custom_fields['custom_meta_keywords'].present?
       
      <<~HTML
        <script>
        document.addEventListener('DOMContentLoaded', function() {
          // We already know we have custom meta data at this point
          const metaTitle = #{topic.custom_fields['custom_meta_title'].to_json};
          const metaDescription = #{topic.custom_fields['custom_meta_description'].to_json};
          const metaKeywords = #{topic.custom_fields['custom_meta_keywords'].to_json};
          
          if (metaTitle) {
            document.title = metaTitle;
            updateMetaTag('og:title', metaTitle);
          }
          
          if (metaDescription) {
            updateMetaTag('description', metaDescription);
            updateMetaTag('og:description', metaDescription);
          }
          
          if (metaKeywords) {
            updateMetaTag('keywords', metaKeywords);
          }
          
          function updateMetaTag(name, content) {
            // Try to find existing meta tag
            let metaTag = document.querySelector(`meta[name="${name}"], meta[property="${name}"]`);
            
            if (metaTag) {
              // Update existing tag
              metaTag.setAttribute('content', content);
            } else {
              // Create new tag
              metaTag = document.createElement('meta');
              if (name.startsWith('og:')) {
                metaTag.setAttribute('property', name);
              } else {
                metaTag.setAttribute('name', name);
              }
              metaTag.setAttribute('content', content);
              document.head.appendChild(metaTag);
            }
          }
        });
        </script>
      HTML
    else
      ""
    end
  end
end
