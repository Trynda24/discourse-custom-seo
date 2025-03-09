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

  # Make these fields available when loading topics - corrected approach
  # Add fields to topic view preloading
  on(:topic_view_init) do |topic_view|
    topic_view.topic.preload_custom_fields(['custom_meta_title', 'custom_meta_description', 'custom_meta_keywords'])
  end
  
  # Set up the controller for API endpoints
  plugin = self
  Discourse::Application.routes.append do
    mount ::DiscourseCustomSeo::Engine, at: '/discourse-custom-seo'
  end

  module ::DiscourseCustomSeo
    class Engine < ::Rails::Engine
      engine_name "discourse_custom_seo"
      isolate_namespace DiscourseCustomSeo
    end
  end

  class ::DiscourseCustomSeo::CustomSeoController < ::ApplicationController
    requires_plugin 'discourse-custom-seo'
    
    def update_meta
      topic_id = params[:topic_id]
      topic = Topic.find_by(id: topic_id)
      
      if !topic
        render json: { error: "Topic not found" }, status: 404
        return
      end
      
      guardian.ensure_can_edit!(topic)
      
      # Update the custom fields
      topic.custom_fields['custom_meta_title'] = params[:custom_title]
      topic.custom_fields['custom_meta_description'] = params[:custom_description]
      topic.custom_fields['custom_meta_keywords'] = params[:custom_keywords]
      topic.save_custom_fields(true)
      
      render json: { success: true }
    rescue Discourse::InvalidAccess
      render json: { error: "You don't have permission to edit this topic" }, status: 403
    end
  end

  DiscourseCustomSeo::Engine.routes.draw do
    post "/update-meta" => "custom_seo#update_meta"
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
