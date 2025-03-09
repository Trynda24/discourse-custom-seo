# name: discourse-custom-seo
# about: Customize meta tags for SEO
# version: 0.1
# authors: Your Name
# url: https://github.com/Trynda24/discourse-custom-seo

register_asset "stylesheets/custom-seo.scss"

after_initialize do
  # Register custom topic fields for storage
  Topic.register_custom_field_type('custom_meta_title', :string)
  Topic.register_custom_field_type('custom_meta_description', :string)
  Topic.register_custom_field_type('custom_meta_keywords', :string)
  
  # Add the fields to the preloaded topic custom fields
  TopicView.add_to_serializer(:topic_view, :custom_meta_title) do
    object.topic.custom_fields['custom_meta_title']
  end
  
  TopicView.add_to_serializer(:topic_view, :custom_meta_description) do
    object.topic.custom_fields['custom_meta_description']
  end
  
  TopicView.add_to_serializer(:topic_view, :custom_meta_keywords) do
    object.topic.custom_fields['custom_meta_keywords']
  end

  # Add fields to the preloaded custom fields
  TopicView.default_post_custom_fields << "custom_meta_title"
  TopicView.default_post_custom_fields << "custom_meta_description"
  TopicView.default_post_custom_fields << "custom_meta_keywords"

  # Register the route for the custom SEO meta update
  Discourse::Application.routes.append do
    put "/discourse-custom-seo/update-meta" => "discourse_custom_seo/meta#update_meta"
  end
  
  module ::DiscourseCustomSEO
    class Engine < ::Rails::Engine
      engine_name "discourse_custom_seo"
      isolate_namespace DiscourseCustomSEO
    end
  end
  
  require_dependency 'application_controller'
  
  class ::DiscourseCustomSEO::MetaController < ::ApplicationController
    requires_plugin 'discourse-custom-seo'
    before_action :ensure_logged_in
  
    def update_meta
      user = current_user
      return render_json_error("You are not authorized") unless user && user.admin?
  
      topic_id = params[:topic_id]
      title = params[:custom_title]
      description = params[:custom_description]
      keywords = params[:custom_keywords]
  
      topic = Topic.find_by(id: topic_id)
      return render_json_error("Topic not found") unless topic
  
      topic.custom_fields['custom_meta_title'] = title
      topic.custom_fields['custom_meta_description'] = description
      topic.custom_fields['custom_meta_keywords'] = keywords
      topic.save!
  
      render json: { success: true }
    end
  end
  
  # Override the application helper to use custom meta data
  ApplicationHelper.class_eval do
    def crawlable_meta_data_with_custom_seo(opts = nil)
      opts ||= {}
      topic = @topic_view&.topic
      
      if topic
        opts[:title] = topic.custom_fields["custom_meta_title"].presence || opts[:title]
        opts[:description] = topic.custom_fields["custom_meta_description"].presence || opts[:description]
        opts[:keywords] = topic.custom_fields["custom_meta_keywords"].presence || opts[:keywords]
      end
      
      crawlable_meta_data_without_custom_seo(opts)
    end
    
    alias_method :crawlable_meta_data_without_custom_seo, :crawlable_meta_data
    alias_method :crawlable_meta_data, :crawlable_meta_data_with_custom_seo
  end
end
