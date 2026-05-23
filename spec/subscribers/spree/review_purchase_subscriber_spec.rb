require 'spec_helper'

RSpec.describe Spree::ReviewPurchaseSubscriber, type: :model do
  let(:store) { create(:store) }
  let(:product) { create(:product, stores: [store]) }
  let(:user) { create(:user) }

  it 'refreshes matching review verified status when a return item is received' do
    variant = create(:reviewable_variant, product: product)
    order = create(:shipped_order, user: user, store: store, variants: [variant])
    review = create(
      :review,
      :verified_purchase,
      :for_variant,
      product: product,
      variant: variant,
      order: order,
      store: store,
      user: user
    )
    return_item = create_received_return_item(order: order, variant: variant)

    described_class.new.call(event_for('return_item.received', return_item))

    expect(review.reload.verified_purchase).to be(false)
  end

  it 'refreshes order reviews when an order is canceled' do
    variant = create(:reviewable_variant, product: product)
    order = create(:shipped_order, user: user, store: store, variants: [variant])
    review = create(
      :review,
      :verified_purchase,
      :for_variant,
      product: product,
      variant: variant,
      order: order,
      store: store,
      user: user
    )
    order.update_columns(state: 'canceled', shipment_state: 'shipped')

    described_class.new.call(event_for('order.canceled', order))

    expect(review.reload.verified_purchase).to be(false)
  end

  private

  def event_for(name, record)
    Spree::Event.new(
      name: name,
      store_id: store.id,
      payload: { id: record.prefixed_id }
    )
  end
end
