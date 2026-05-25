module SpreeReviews
  class Engine < Rails::Engine
    require 'spree/core'
    isolate_namespace Spree
    engine_name 'spree_reviews'

    config.paths.add 'app/subscribers', eager_load: true

    config.generators do |g|
      g.test_framework :rspec
    end

    initializer 'spree_reviews.environment', before: :load_config_initializers do |_app|
      SpreeReviews::Config = SpreeReviews::Configuration.new
    end

    initializer 'spree_reviews.assets' do |app|
      if app.config.respond_to?(:assets)
        app.config.assets.paths << root.join('app/javascript')
        app.config.assets.precompile += %w[spree_reviews_manifest]
      end
    end

    initializer 'spree_reviews.importmap', before: 'importmap' do |app|
      if app.config.respond_to?(:importmap)
        app.config.importmap.paths << root.join('config/importmap.rb')
        # https://github.com/rails/importmap-rails?tab=readme-ov-file#sweeping-the-cache-in-development-and-test
        app.config.importmap.cache_sweepers << root.join('app/javascript')
      end
    end

    initializer 'spree_reviews.admin_importmap', after: 'spree.admin.importmap' do |app|
      if app.config.respond_to?(:spree_admin) && app.config.spree_admin.respond_to?(:importmap)
        app.config.spree_admin.importmap.draw(root.join('config/importmap.rb'))
        app.config.spree_admin.cache_sweepers << root.join('app/javascript')
      end
    end

    config.after_initialize do
      require_dependency root.join('app/subscribers/spree/review_purchase_subscriber').to_s

      unless Spree.subscribers.include?(Spree::ReviewPurchaseSubscriber)
        Spree.subscribers << Spree::ReviewPurchaseSubscriber
      end
    end

    config.to_prepare do
      require_dependency SpreeReviews::Engine.root.join('app/models/spree_reviews/product_decorator').to_s
    end
  end
end
