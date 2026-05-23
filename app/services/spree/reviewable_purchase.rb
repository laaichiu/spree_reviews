module Spree
  class ReviewablePurchase
    REVIEWABLE_INVENTORY_STATES = %w[shipped returned].freeze
    COMPLETED_RETURN_RECEPTION_STATUSES = %w[received].freeze
    COMPLETED_REIMBURSEMENT_STATUSES = %w[reimbursed].freeze

    attr_reader :order, :product, :variant

    def initialize(order:, product:, variant: nil)
      @order = order
      @product = product
      @variant = variant
    end

    def reviewable?
      return false unless order_reviewable?

      reviewable_variant_ids.any?
    end

    def reviewable_variant?(candidate_variant)
      return false unless order_reviewable?

      candidate_variant.present? && reviewable_quantity_for_variant_id(candidate_variant.id).positive?
    end

    def reviewable_variant_ids
      return [] unless order_reviewable?

      @reviewable_variant_ids ||= candidate_variant_ids.select do |variant_id|
        reviewable_quantity_for_variant_id(variant_id).positive?
      end
    end

    def target_variant
      return variant if variant.present? && reviewable_variant?(variant)

      variant_ids = reviewable_variant_ids
      return unless variant_ids.one?

      variant_by_id(variant_ids.first)
    end

    private

    def order_reviewable?
        order.present? &&
        order.completed_at.present? &&
        order_shipped? &&
        order.state != 'canceled'
    end

    def order_shipped?
      order.shipment_state == 'shipped' ||
        inventory_units.any? { |inventory_unit| reviewable_inventory_unit?(inventory_unit) }
    end

    def reviewable_quantity_for_variant_id(variant_id)
      gross_quantity_for_variant_id(variant_id) - returned_quantity_for_variant_id(variant_id)
    end

    def gross_quantity_for_variant_id(variant_id)
      units = inventory_units_for_variant(variant_id)
      if units.any?
        return units.sum do |inventory_unit|
          reviewable_inventory_unit?(inventory_unit) ? inventory_unit.quantity.to_i : 0
        end
      end

      matching_line_items(variant_id).sum { |line_item| line_item.quantity.to_i }
    end

    def returned_quantity_for_variant_id(variant_id)
      inventory_units_for_variant(variant_id).sum do |inventory_unit|
        inventory_unit.return_items.sum do |return_item|
          completed_return_item?(return_item) ? return_item.return_quantity.to_i : 0
        end
      end
    end

    def candidate_variant_ids
      return [] if order.blank? || product.blank?
      return [variant.id] if variant.present?

      line_items.select { |line_item| line_item.variant&.product_id == product.id }.
        filter_map(&:variant_id).
        uniq
    end

    def matching_line_items(variant_id)
      line_items.select { |line_item| line_item.variant_id == variant_id }
    end

    def line_items
      @line_items ||= order.line_items.includes(:variant).to_a
    end

    def inventory_units_for_variant(variant_id)
      inventory_units.select { |inventory_unit| inventory_unit.variant_id == variant_id }
    end

    def inventory_units
      @inventory_units ||= order.inventory_units.includes(return_items: :reimbursement).to_a
    end

    def reviewable_inventory_unit?(inventory_unit)
      REVIEWABLE_INVENTORY_STATES.include?(inventory_unit.state)
    end

    def completed_return_item?(return_item)
      COMPLETED_RETURN_RECEPTION_STATUSES.include?(return_item.reception_status) ||
        return_item.reimbursement_id.present? ||
        COMPLETED_REIMBURSEMENT_STATUSES.include?(return_item.reimbursement&.reimbursement_status)
    end

    def variant_by_id(variant_id)
      line_items.find { |line_item| line_item.variant_id == variant_id }&.variant ||
        Spree::Variant.find_by(id: variant_id)
    end
  end
end
