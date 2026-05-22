require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::ReviewsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let(:product) { create(:product, stores: [store]) }
  let!(:review) do
    create(
      :review,
      product: product,
      store: store,
      title: 'Needs review',
      status: 'pending',
      private_metadata: { moderation: 'queued' }
    )
  end

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'returns reviews for the current store' do
      other_store = create(:store)
      create(:review, store: other_store)

      get :index, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |item| item['id'] }).to contain_exactly(review.prefixed_id)
      expect(json_response['data'].first['store_id']).to eq(store.prefixed_id)
    end

    it 'supports admin ransack filters' do
      create(:review, :approved, product: product, store: store)

      get :index, params: { q: { status_eq: 'pending' } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |item| item['id'] }).to eq([review.prefixed_id])
    end
  end

  describe 'GET #show' do
    it 'serializes admin-only fields' do
      get :show, params: { id: review.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(review.prefixed_id)
      expect(json_response['metadata']).to eq('moderation' => 'queued')
      expect(json_response['private_metadata']).to eq('moderation' => 'queued')
      expect(json_response['product_id']).to eq(product.prefixed_id)
    end
  end

  describe 'PATCH #update' do
    it 'updates review moderation fields' do
      patch :update,
            params: {
              id: review.prefixed_id,
              title: 'Reviewed title',
              status: 'approved',
              verified_purchase: true,
              metadata: { moderation: 'approved' }
            },
            as: :json

      expect(response).to have_http_status(:ok)
      expect(review.reload).to have_attributes(
        title: 'Reviewed title',
        status: 'approved',
        verified_purchase: true
      )
      expect(review.metadata).to eq('moderation' => 'approved')
    end
  end

  describe 'POST #approve' do
    it 'approves a review' do
      post :approve, params: { id: review.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(review.reload.status).to eq('approved')
      expect(json_response['status']).to eq('approved')
    end
  end

  describe 'POST #reject' do
    it 'rejects a review' do
      post :reject, params: { id: review.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(review.reload.status).to eq('rejected')
      expect(json_response['status']).to eq('rejected')
    end
  end

  describe 'DELETE #destroy' do
    it 'deletes a review' do
      expect {
        delete :destroy, params: { id: review.prefixed_id }, as: :json
      }.to change(Spree::Review, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
