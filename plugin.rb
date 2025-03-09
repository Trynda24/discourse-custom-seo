# name: discourse-custom-seo
# about: Customize meta tags for SEO
# version: 0.1
# authors: Your Name
# url: https://github.com/yourusername/discourse-custom-seo

register_asset "stylesheets/custom-seo.scss"

after_initialize do
  # Register the route for the custom SEO meta update
  Discourse::Application.routes.append do
    put "/discourse-custom-seo/update-meta" => "discourse_custom_seo/meta#update_meta"
  end
end

module ::DiscourseCustomSEO
  class Engine < ::Rails::Engine
    engine_name "discourse_custom_seo"
    isolate_namespace DiscourseCustomSEO
  end
end

require_dependency 'application_controller'

class DiscourseCustomSEO::MetaController < ::ApplicationController
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

    render_json_success
  end
end

Discourse::Application.routes.append do
  put "/discourse-custom-seo/update-meta" => "discourse_custom_seo/meta#update_meta"
end

register_editable_user_custom_field :custom_meta_title
register_editable_user_custom_field :custom_meta_description
register_editable_user_custom_field :custom_meta_keywords

TopicView.default_post_custom_fields << "custom_meta_title"
TopicView.default_post_custom_fields << "custom_meta_description"
TopicView.default_post_custom_fields << "custom_meta_keywords"

reloadable_patch do
  ApplicationHelper.module_eval do
    def crawlable_meta_data(opts = nil)
      opts ||= {}
      topic = @topic_view&.topic
      if topic
        opts[:title] = topic.custom_fields["custom_meta_title"].presence || opts[:title]
        opts[:description] = topic.custom_fields["custom_meta_description"].presence || opts[:description]
        opts[:keywords] = topic.custom_fields["custom_meta_keywords"].presence || opts[:keywords]
      end
      super(opts)
    end
  end
end
