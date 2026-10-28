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
