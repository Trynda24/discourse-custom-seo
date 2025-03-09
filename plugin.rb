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
  add_to_serializer(:topic_view, :custom_meta_title) { object.topic.custom_fields['custom_meta_title'] }
  add_to_serializer(:topic_view, :custom_meta_description) { object.topic.custom_fields['custom_meta_description'] }
  add_to_serializer(:topic_view, :custom_meta_keywords) { object.topic.custom_fields['custom_meta_keywords'] }

  # Ensure fields are available when loading topics
  TopicView.default_post_custom_fields += %w[custom_meta_title custom_meta_description custom_meta_keywords]

  # Define API route correctly
  Discourse::Application.routes.append do
    put "/discourse-custom-seo/update-meta" => "discourse_custom_seo#update_meta"
  end

  # Create a custom controller for API
  module ::DiscourseCustomSeo
    class SeoController < ::ApplicationController
      requires_plugin "discourse-custom-seo"

      before_action :ensure_logged_in

      def update_meta
        topic = Topic.find_by(id: params[:topic_id])
        guardian = Guardian.new(current_user)

        if !topic
          render json: { error: "Topic not found" }, status: 404
        elsif !guardian.can_edit?(topic)
          render json: { error: "You don't have permission to edit this topic" }, status: 403
        else
          topic.custom_fields['custom_meta_title'] = params[:custom_title]
          topic.custom_fields['custom_meta_description'] = params[:custom_description]
          topic.custom_fields['custom_meta_keywords'] = params[:custom_keywords]
          topic.save_custom_fields(true)
          render json: { success: true }
        end
      end
    end
  end

  # Register the controller
  register_post_custom_field_type("custom_meta_title", :string)
  register_post_custom_field_type("custom_meta_description", :string)
  register_post_custom_field_type("custom_meta_keywords", :string)

  # Override meta tags properly
  module ::DiscourseCustomSeo::MetaDataOverride
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

  ApplicationHelper.prepend(::DiscourseCustomSeo::MetaDataOverride)
end
