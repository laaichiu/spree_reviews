module SpreeReviews
  class Configuration < Spree::Preferences::Configuration
    preference :auto_approve_reviews, :boolean, default: false
    preference :max_images_per_review, :integer, default: 5
    preference :max_image_size_megabytes, :integer, default: 10
  end
end
