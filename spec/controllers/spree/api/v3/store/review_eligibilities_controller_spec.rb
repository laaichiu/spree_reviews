require 'spec_helper'
require 'spree/api/testing_support/v3/base'

RSpec.describe Spree::Api::V3::Store::ReviewEligibilitiesController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let(:product) { create(:product, stores: [store]) }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  describe 'GET #show' do
    it 'returns login_required for guests' do
      get :show, params: { product_id: product.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(json_response['can_review']).to be(false)
      expect(json_response['reason']).to eq('login_required')
      expect(json_response['verified_purchase']).to be(false)
    end

    it 'returns not_purchased for authenticated customers without a shipped purchase' do
      request.headers['Authorization'] = "Bearer #{jwt_token}"
      create(:order_ready_to_ship, user: user, store: store, variants: [product.master])

      get :show, params: { product_id: product.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(json_response['can_review']).to be(false)
      expect(json_response['reason']).to eq('not_purchased')
      expect(json_response['verified_purchase']).to be(false)
    end

    it 'allows authenticated customers with a shipped purchase' do
      request.headers['Authorization'] = "Bearer #{jwt_token}"
      order = create(:shipped_order, user: user, store: store, variants: [product.master])
      order.update!(shipment_state: 'shipped')

      get :show, params: { product_id: product.prefixed_id, order_id: order.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(json_response['can_review']).to be(true)
      expect(json_response['reason']).to be_nil
      expect(json_response['verified_purchase']).to be(true)
      expect(json_response['order_id']).to eq(order.prefixed_id)
      expect(json_response['eligible_order_id']).to eq(order.prefixed_id)
    end

    it 'returns already_reviewed when the customer already reviewed the product' do
      request.headers['Authorization'] = "Bearer #{jwt_token}"
      order = create(:shipped_order, user: user, store: store, variants: [product.master])
      order.update!(shipment_state: 'shipped')
      review = create(:review, product: product, order: order, store: store, user: user)

      get :show, params: { product_id: product.prefixed_id, order_id: order.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(json_response['can_review']).to be(false)
      expect(json_response['reason']).to eq('already_reviewed')
      expect(json_response['already_reviewed']).to be(true)
      expect(json_response['review_id']).to eq(review.prefixed_id)
    end

    it 'returns already_reviewed for legacy reviews missing order and variant links' do
      request.headers['Authorization'] = "Bearer #{jwt_token}"
      variant = create(:reviewable_variant, product: product)
      order = create(:shipped_order, user: user, store: store, variants: [variant])
      order.update!(shipment_state: 'shipped')
      review = create(:review, product: product, order: nil, variant: nil, store: store, user: user)

      get :show, params: { product_id: product.prefixed_id, variant_id: variant.prefixed_id, order_id: order.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(json_response['can_review']).to be(false)
      expect(json_response['reason']).to eq('already_reviewed')
      expect(json_response['already_reviewed']).to be(true)
      expect(json_response['review_id']).to eq(review.prefixed_id)
    end

    it 'checks eligibility for the requested variant' do
      request.headers['Authorization'] = "Bearer #{jwt_token}"
      variant = create(:reviewable_variant, product: product)
      other_variant = create(:reviewable_variant, product: product)
      order = create(:shipped_order, user: user, store: store, variants: [other_variant])
      reviewed_order = create(:shipped_order, user: user, store: store, variants: [variant])
      order.update!(shipment_state: 'shipped')
      reviewed_order.update!(shipment_state: 'shipped')
      create(:review, :for_variant, product: product, variant: variant, order: reviewed_order, store: store, user: user)

      get :show, params: { product_id: product.prefixed_id, variant_id: other_variant.prefixed_id, order_id: order.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(json_response['can_review']).to be(true)
      expect(json_response['variant_id']).to eq(other_variant.prefixed_id)
      expect(json_response['order_id']).to eq(order.prefixed_id)
    end

    it 'allows the same variant again when it belongs to a different shipped order' do
      request.headers['Authorization'] = "Bearer #{jwt_token}"
      variant = create(:reviewable_variant, product: product)
      reviewed_order = create(:shipped_order, user: user, store: store, variants: [variant])
      new_order = create(:shipped_order, user: user, store: store, variants: [variant])
      reviewed_order.update!(shipment_state: 'shipped')
      new_order.update!(shipment_state: 'shipped')
      create(:review, :for_variant, product: product, variant: variant, order: reviewed_order, store: store, user: user)

      get :show, params: { product_id: product.prefixed_id, variant_id: variant.prefixed_id, order_id: new_order.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(json_response['can_review']).to be(true)
      expect(json_response['eligible_order_id']).to eq(new_order.prefixed_id)
    end
  end
end
