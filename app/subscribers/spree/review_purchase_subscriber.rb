module Spree
  class ReviewPurchaseSubscriber
    SUBSCRIPTION_PATTERNS = ['return_item.received', 'reimbursement.reimbursed', 'order.canceled'].freeze
    SUBSCRIPTION_OPTIONS = { async: false }.freeze

    def self.subscription_patterns
      SUBSCRIPTION_PATTERNS
    end

    def self.subscription_options
      SUBSCRIPTION_OPTIONS
    end

    def self.call(event)
      new.call(event)
    end

    def call(event)
      case event.name
      when 'return_item.received'
        sync_for_return_item(event)
      when 'reimbursement.reimbursed'
        sync_for_reimbursement(event)
      when 'order.canceled'
        sync_for_order(event)
      end
    end

    def sync_for_return_item(event)
      return_item = find_record(Spree::ReturnItem, event)
      return unless return_item&.inventory_unit

      Spree::ReviewVerifiedPurchaseStatus.sync_for_order_variant!(
        order: return_item.inventory_unit.order,
        variant: return_item.inventory_unit.variant
      )
    end

    def sync_for_reimbursement(event)
      reimbursement = find_record(Spree::Reimbursement, event)
      return if reimbursement.blank?

      reimbursement.return_items.includes(inventory_unit: :variant).each do |return_item|
        next unless return_item.inventory_unit

        Spree::ReviewVerifiedPurchaseStatus.sync_for_order_variant!(
          order: return_item.inventory_unit.order,
          variant: return_item.inventory_unit.variant
        )
      end
    end

    def sync_for_order(event)
      order = find_record(Spree::Order, event)
      Spree::ReviewVerifiedPurchaseStatus.sync_for_order!(order)
    end

    private

    def find_record(model_class, event)
      id = event.payload['id']
      return if id.blank?

      if model_class.respond_to?(:find_by_param)
        model_class.find_by_param(id)
      else
        model_class.find_by(id: id)
      end
    rescue ActiveRecord::RecordNotFound
      nil
    end
  end
end
