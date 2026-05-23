module Spree
  class ReviewPurchaseAttribution
    Target = Struct.new(:order, :variant, keyword_init: true)

    def self.backfill_scope
      Spree::Review.where.not(user_id: nil).where('order_id IS NULL OR variant_id IS NULL')
    end

    def initialize(review)
      @review = review
    end

    def target
      return unless attributable?

      target_order_and_variant
    end

    def call
      attribution_target = target
      return false if attribution_target.blank?

      attributes = {}
      attributes[:order] = attribution_target.order if review.order.blank?
      attributes[:variant] = attribution_target.variant if review.variant.blank? && attribution_target.variant.present?
      return false if attributes.empty?

      review.update!(attributes)
    end

    private

    attr_reader :review

    def attributable?
      review.user_id.present? && review.product_id.present? && review.store_id.present?
    end

    def target_order_and_variant
      candidate_orders.each do |order|
        variant = target_variant_for(order)
        next if duplicate_review_exists?(order, variant)

        return Target.new(order: order, variant: variant)
      end

      nil
    end

    def candidate_orders
      orders = Spree::Order.complete.shipped.not_canceled.
               where(user_id: review.user_id, store_id: review.store_id).
               joins(line_items: :variant).
               merge(candidate_variant_scope).
               includes(line_items: :variant).
               distinct.
               to_a

      orders.sort_by { |order| order_sort_key(order) }
    end

    def candidate_variant_scope
      if review.variant_id.present?
        Spree::Variant.where(id: review.variant_id)
      else
        Spree::Variant.where(product_id: review.product_id)
      end
    end

    def order_sort_key(order)
      return [1, 0, -order.id] if review.created_at.blank? || order.completed_at.blank?

      completed_after_review = order.completed_at > review.created_at ? 1 : 0
      [completed_after_review, (review.created_at - order.completed_at).abs, -order.id]
    end

    def target_variant_for(order)
      return review.variant if review.variant.present?

      matching_line_items = order.line_items.select { |line_item| line_item.variant&.product_id == review.product_id }
      variant_ids = matching_line_items.map(&:variant_id).uniq
      return if variant_ids.size != 1

      matching_line_items.first.variant
    end

    def duplicate_review_exists?(order, variant)
      reviews = Spree::Review.
                where(store_id: review.store_id, order_id: order.id, product_id: review.product_id, user_id: review.user_id).
                where.not(id: review.id)

      if variant.present?
        reviews.where(variant_id: [variant.id, nil]).exists?
      else
        reviews.where(variant_id: nil).exists?
      end
    end
  end
end
