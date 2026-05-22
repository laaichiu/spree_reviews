pin 'application-spree-reviews', to: 'spree_reviews/application.js', preload: false

pin_all_from SpreeReviews::Engine.root.join('app/javascript/spree_reviews/controllers'),
             under: 'spree_reviews/controllers',
             to:    'spree_reviews/controllers',
             preload: 'application-spree-reviews'
