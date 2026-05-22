module Spree
  class ReviewEligibility
    REASON_LOGIN_REQUIRED = 'login_required'.freeze
    REASON_NOT_PURCHASED = 'not_purchased'.freeze
    REASON_ALREADY_REVIEWED = 'already_reviewed'.freeze

    attr_reader :product, :store, :user

    def initialize(product:, store:, user:)
      @product = product
      @store = store
      @user = user
    end

    def can_review?
      reason.nil?
    end

    def reason
      return REASON_LOGIN_REQUIRED unless authenticated?
      return REASON_ALREADY_REVIEWED if already_reviewed?
      return REASON_NOT_PURCHASED unless verified_purchase?
    end

    def verified_purchase?
      eligible_order.present?
    end

    def already_reviewed?
      existing_review.present?
    end

    def existing_review
      return if user.blank?
      return @existing_review if defined?(@existing_review)

      @existing_review = Spree::Review.for_store(store).for_product(product).find_by(user_id: user.id)
    end

    def eligible_order
      return if user.blank?
      return @eligible_order if defined?(@eligible_order)

      @eligible_order = eligible_orders.first
    end

    private

    def authenticated?
      user.present?
    end

    def eligible_orders
      Spree::Order.complete.shipped.not_canceled.
        where(user_id: user.id, store_id: store.id).
        joins(line_items: :variant).
        where(Spree::Variant.table_name => { product_id: product.id }).
        distinct.
        order(completed_at: :desc, id: :desc)
    end
  end
end
