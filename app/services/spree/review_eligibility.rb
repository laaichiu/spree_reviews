module Spree
  class ReviewEligibility
    REASON_LOGIN_REQUIRED = 'login_required'.freeze
    REASON_NOT_PURCHASED = 'not_purchased'.freeze
    REASON_ALREADY_REVIEWED = 'already_reviewed'.freeze

    attr_reader :product, :store, :user, :variant

    def initialize(product:, store:, user:, variant: nil)
      @product = product
      @store = store
      @user = user
      @variant = variant
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

      reviews = Spree::Review.for_store(store).for_product(product).where(user_id: user.id)
      @existing_review = if variant.present?
                           reviews.find_by(variant: variant)
                         else
                           reviews.find_by(variant_id: nil)
                         end
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
        merge(eligible_variant_scope).
        distinct.
        order(completed_at: :desc, id: :desc)
    end

    def eligible_variant_scope
      if variant.present?
        Spree::Variant.where(id: variant.id)
      else
        Spree::Variant.where(product_id: product.id)
      end
    end
  end
end
