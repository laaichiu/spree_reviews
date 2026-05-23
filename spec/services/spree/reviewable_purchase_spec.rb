require 'spec_helper'

RSpec.describe Spree::ReviewablePurchase, type: :service do
  let(:store) { create(:store) }
  let(:product) { create(:product, stores: [store]) }
  let(:user) { create(:user) }

  it 'is reviewable when the shipped variant has not been returned' do
    variant = create(:reviewable_variant, product: product)
    order = create(:shipped_order, user: user, store: store, variants: [variant])

    purchase = described_class.new(order: order, product: product, variant: variant)

    expect(purchase).to be_reviewable
    expect(purchase).to be_reviewable_variant(variant)
    expect(purchase.target_variant).to eq(variant)
  end

  it 'is not reviewable before the order has shipped' do
    variant = create(:reviewable_variant, product: product)
    order = create(:order_ready_to_ship, user: user, store: store, variants: [variant])

    purchase = described_class.new(order: order, product: product, variant: variant)

    expect(purchase).not_to be_reviewable
    expect(purchase.reviewable_variant_ids).to be_empty
  end

  it 'allows shipped variants from a partially canceled order' do
    variant = create(:reviewable_variant, product: product)
    order = create(:shipped_order, user: user, store: store, variants: [variant])
    order.update_columns(state: 'partially_canceled', shipment_state: 'shipped')

    purchase = described_class.new(order: order, product: product, variant: variant)

    expect(purchase).to be_reviewable
  end

  it 'rejects fully canceled orders' do
    variant = create(:reviewable_variant, product: product)
    order = create(:shipped_order, user: user, store: store, variants: [variant])
    order.update_columns(state: 'canceled', shipment_state: 'shipped')

    purchase = described_class.new(order: order, product: product, variant: variant)

    expect(purchase).not_to be_reviewable
  end

  it 'is not reviewable when the purchased variant has been fully returned' do
    variant = create(:reviewable_variant, product: product)
    order = create(:shipped_order, user: user, store: store, variants: [variant])
    create_received_return_item(order: order, variant: variant)

    purchase = described_class.new(order: order, product: product, variant: variant)

    expect(purchase).not_to be_reviewable
    expect(purchase.reviewable_variant_ids).to be_empty
  end

  it 'stays reviewable when only part of the purchased variant quantity was returned' do
    variant = create(:reviewable_variant, product: product)
    order = create(:shipped_order, user: user, store: store, variants: [variant])
    line_item = order.line_items.find_by!(variant: variant)
    inventory_unit = order.inventory_units.find_by!(line_item: line_item, variant: variant)
    line_item.update!(quantity: 2)
    inventory_unit.update!(quantity: 2)

    create_received_return_item(order: order, variant: variant, quantity: 1)

    purchase = described_class.new(order: order.reload, product: product, variant: variant)

    expect(purchase).to be_reviewable
    expect(purchase).to be_reviewable_variant(variant)
  end

  it 'keeps other variants in the same order reviewable after one variant is returned' do
    returned_variant = create(:reviewable_variant, product: product)
    kept_variant = create(:reviewable_variant, product: product)
    order = create(:shipped_order, user: user, store: store, variants: [returned_variant, kept_variant])
    create_received_return_item(order: order, variant: returned_variant)

    product_purchase = described_class.new(order: order, product: product)
    returned_purchase = described_class.new(order: order, product: product, variant: returned_variant)
    kept_purchase = described_class.new(order: order, product: product, variant: kept_variant)

    expect(returned_purchase).not_to be_reviewable
    expect(kept_purchase).to be_reviewable
    expect(product_purchase.reviewable_variant_ids).to contain_exactly(kept_variant.id)
    expect(product_purchase.target_variant).to eq(kept_variant)
  end
end
