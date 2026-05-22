module SpreeReviews
  module ProductDecorator
    def self.prepended(base)
      base.has_many :reviews, class_name: 'Spree::Review', dependent: :destroy, inverse_of: :product
      base.has_one :review_summary, class_name: 'Spree::ProductReviewSummary', dependent: :destroy, inverse_of: :product
    end
  end
end

Spree::Product.prepend SpreeReviews::ProductDecorator unless Spree::Product < SpreeReviews::ProductDecorator
