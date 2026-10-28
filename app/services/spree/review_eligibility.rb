module Spree
  class ReviewEligibility
    REASON_LOGIN_REQUIRED = 'login_required'.freeze
    REASON_NOT_PURCHASED = 'not_purchased'.freeze
    REASON_ALREADY_REVIEWED = 'already_reviewed'.freeze

    attr_reader :product, :store, :user, :variant, :order

    def initialize(product:, store:, user:, variant: nil, order: nil)
      @product = product
      @store = store
      @user = user
      @variant = variant
      @order = order
    end

    def can_review?
      reason.nil?
    end

    def reason
      return REASON_LOGIN_REQUIRED unless authenticated?
      return REASON_NOT_PURCHASED unless verified_purchase?
      return REASON_ALREADY_REVIEWED if already_reviewed?
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

      review_order = order || eligible_order
      return @existing_review = nil if review_order.blank?

      @existing_review = existing_review_for_order(review_order)
    end

    def eligible_order
      return if user.blank?
      return @eligible_order if defined?(@eligible_order)

      @eligible_order = if order.present?
                          eligible_orders.find { |candidate| candidate.id == order.id }
                        else
                          first_unreviewed_eligible_order || eligible_orders.first
                        end
    end

    private

    def authenticated?
      user.present?
    end

    def first_unreviewed_eligible_order
      eligible_orders.detect { |candidate| existing_review_for_order(candidate).blank? }
    end

    def existing_review_for_order(review_order)
      reviews = Spree::Review.for_store(store).for_product(product).where(user_id: user.id)
      ordered_reviews = reviews.where(order: review_order)

      exact_review = if variant.present?
                       ordered_reviews.find_by(variant: variant) ||
                         ordered_reviews.find_by(variant_id: nil)
                     else
                       ordered_reviews.find_by(variant_id: nil)
                     end
      exact_review || legacy_existing_review_for_order(reviews, review_order)
    end

    def legacy_existing_review_for_order(reviews, review_order)
      legacy_reviews = reviews.where(order_id: nil)
      legacy_reviews = if variant.present?
                         legacy_reviews.where(variant_id: [variant.id, nil])
                       else
                         legacy_reviews.where(variant_id: nil)
                       end

      legacy_reviews.recent_first.detect do |legacy_review|
        legacy_review_attributed_to_order?(legacy_review, review_order)
      end
    end

    def legacy_review_attributed_to_order?(legacy_review, review_order)
      attribution_target = Spree::ReviewPurchaseAttribution.new(legacy_review).target
      return false if attribution_target.blank? || attribution_target.order.id != review_order.id

      variant.blank? ||
        attribution_target.variant.blank? ||
        attribution_target.variant.id == variant.id
    end

    def eligible_orders
      @eligible_orders ||= Spree::Order.complete.
        where(customer_id: user.id, store_id: store.id).
        where.not(status: 'canceled').
        joins(line_items: :variant).
        merge(eligible_variant_scope).
        includes({ fulfillment_items: { return_line_items: :return } }, line_items: :variant).
        distinct.
        order(completed_at: :desc, id: :desc).
        to_a.
        select { |candidate| reviewable_purchase_for(candidate).reviewable? }
    end

    def eligible_variant_scope
      if variant.present?
        Spree::Variant.where(id: variant.id)
      else
        Spree::Variant.where(product_id: product.id)
      end
    end

    def reviewable_purchase_for(candidate_order)
      Spree::ReviewablePurchase.new(order: candidate_order, product: product, variant: variant)
    end
  end
end
