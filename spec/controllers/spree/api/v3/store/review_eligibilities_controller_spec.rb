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

      get :show, params: { product_id: product.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(json_response['can_review']).to be(true)
      expect(json_response['reason']).to be_nil
      expect(json_response['verified_purchase']).to be(true)
      expect(json_response['eligible_order_id']).to eq(order.prefixed_id)
    end

    it 'returns already_reviewed when the customer already reviewed the product' do
      request.headers['Authorization'] = "Bearer #{jwt_token}"
      create(:shipped_order, user: user, store: store, variants: [product.master]).update!(shipment_state: 'shipped')
      review = create(:review, product: product, store: store, user: user)

      get :show, params: { product_id: product.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(json_response['can_review']).to be(false)
      expect(json_response['reason']).to eq('already_reviewed')
      expect(json_response['already_reviewed']).to be(true)
      expect(json_response['review_id']).to eq(review.prefixed_id)
    end
  end
end
