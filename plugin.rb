# name: auto-insert-wiki
# version: 0.1.1
# author: Muhlis Budi Cahyono <muhlisbc@gmail.com>
# url: https://github.com/muhlisbc/discourse-auto-insert-wiki-plugin

after_initialize {
  class ::AutoInsertWiki
    attr_reader :category_slugs

    def initialize
      @categories = Category.where(slug: %w(investments platforms misc))
      @category_slugs = @categories.pluck(:slug)
      username = Rails.env.production? ? "Summary" : "discobot"
      @creator = User.find_by(username_lower: username)

      raise "Can't find user: #{username}" unless @creator
    end

    def bulk_insert
      @categories.each do |category|
        raw = AutoInsertWiki.wiki_for(category)

        category.topics.each do |topic|
          insert_wiki(topic, raw)
        end

        category.subcategories.each do |c|
          c.topics.each do |topic|
            insert_wiki(topic, raw)
          end
        end
      end
    end

    def insert_wiki(topic, raw = nil)
      op = topic.first_post

      return if (!op || op.wiki)

      Post.transaction {
        topic.posts.order(post_number: :desc).each do |post|
          post.update_column(:sort_order, post.sort_order + 1)
          post.update_column(:post_number, post.post_number + 1)
        end

        raw ||= begin
          category_slug = topic.category.slug
          parent_category_slug = topic.category.parent_category&.slug
          AutoInsertWiki.wiki_for(category_slug, parent_category_slug)
        end

        post = PostCreator.create(@creator, raw: raw, topic_id: topic.id, no_bump: true)
        post.update_column(:sort_order, 1)
        post.update_column(:post_number, 1)
        post.update_column(:wiki, true)
      }
    end

    def self.wiki_map
      {
        "investments" => "deal",
        "platforms" => "general",
        "staff" => "general",
        "misc" => "general",
        "liaisons" => "general"
      }
    end

    def self.wiki_for(*categories)
      template = nil

      categories.each do |category|
        template ||= wiki_map[category]
      end

      I18n.t("auto_insert_wiki.#{template}_wiki")
    end

    def self.templates_map
      {
        "investments" => "deal"
      }
    end

    def self.template_for(*categories)
      template = nil

      categories.each do |category|
        template ||= templates_map[category]
      end

      I18n.t("auto_insert_wiki.#{template}_template")
    end
  end

  on(:topic_created) do |topic, _opts, _user|
    if !topic.private_message? && topic.category

      category_slug = topic.category.slug
      parent_category_slug = topic.category.parent_category&.slug
      aiw = AutoInsertWiki.new

      if aiw.category_slugs.include?(category_slug) || aiw.category_slugs.include?(parent_category_slug)
        aiw.insert_wiki(topic)
      end
    end
  end

  require_dependency "application_controller"
  class ::AutoInsertWikiController < ::ApplicationController
    before_action :ensure_logged_in

    def create
      topic = Topic.find(params[:id])

      guardian.ensure_can_see_topic!(topic)

      if !topic.private_message? && topic.category

        category_slug = topic.category.slug
        parent_category_slug = topic.category.parent_category&.slug
        aiw = AutoInsertWiki.new

        if aiw.category_slugs.include?(category_slug) || aiw.category_slugs.include?(parent_category_slug)
          template = AutoInsertWiki.template_for(category_slug, parent_category_slug)
          post = topic.first_post

          post.revise(current_user, { raw: template }, bypass_bump: true, skip_validations: true)
        end
      end

      render json: success_json
    end
  end

  ::Discourse::Application.routes.append do
    post "/auto-insert-wiki" => "auto_insert_wiki#create"
  end
}
