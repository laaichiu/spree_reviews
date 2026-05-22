require 'spec_helper'

RSpec.describe Spree::ReviewEligibility, type: :model do
  let(:store) { create(:store) }
  let(:product) { create(:product, stores: [store]) }
  let(:user) { create(:user) }

  subject(:eligibility) { described_class.new(product: product, store: store, user: user) }

  it 'requires authentication' do
    eligibility = described_class.new(product: product, store: store, user: nil)

    expect(eligibility).not_to be_can_review
    expect(eligibility.reason).to eq('login_required')
  end

  it 'requires a shipped order containing the product' do
    create(:order_ready_to_ship, user: user, store: store, variants: [product.master])

    expect(eligibility).not_to be_can_review
    expect(eligibility.reason).to eq('not_purchased')
    expect(eligibility).not_to be_verified_purchase
  end

  it 'allows customers with a shipped order containing the product' do
    order = create(:shipped_order, user: user, store: store, variants: [product.master])
    order.update!(shipment_state: 'shipped')

    expect(eligibility).to be_can_review
    expect(eligibility.reason).to be_nil
    expect(eligibility).to be_verified_purchase
    expect(eligibility.eligible_order).to eq(order)
  end

  it 'does not allow duplicate reviews by the same customer for the product' do
    create(:shipped_order, user: user, store: store, variants: [product.master]).update!(shipment_state: 'shipped')
    review = create(:review, product: product, store: store, user: user)

    expect(eligibility).not_to be_can_review
    expect(eligibility.reason).to eq('already_reviewed')
    expect(eligibility.existing_review).to eq(review)
  end
end
