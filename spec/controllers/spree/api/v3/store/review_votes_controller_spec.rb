require 'spec_helper'
require 'spree/api/testing_support/v3/base'

RSpec.describe Spree::Api::V3::Store::ReviewVotesController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let(:review) { create(:review, :approved, store: store) }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  describe 'POST #create' do
    it 'creates a helpful vote and returns updated counters' do
      expect {
        post :create, params: { review_id: review.prefixed_id, vote: 'helpful' }
      }.to change(Spree::ReviewVote, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['helpful_count']).to eq(1)
      expect(json_response['current_vote']).to eq('helpful')
    end

    it 'updates an existing actor vote instead of creating a duplicate' do
      post :create, params: { review_id: review.prefixed_id, vote: 'helpful' }

      expect {
        post :create, params: { review_id: review.prefixed_id, vote: 'not_helpful' }
      }.not_to change(Spree::ReviewVote, :count)

      expect(response).to have_http_status(:ok)
      expect(json_response['helpful_count']).to eq(0)
      expect(json_response['not_helpful_count']).to eq(1)
      expect(json_response['current_vote']).to eq('not_helpful')
    end

    it 'removes an existing actor vote when the same vote is clicked again' do
      post :create, params: { review_id: review.prefixed_id, vote: 'helpful' }

      expect {
        post :create, params: { review_id: review.prefixed_id, vote: 'helpful' }
      }.to change(Spree::ReviewVote, :count).by(-1)

      expect(response).to have_http_status(:ok)
      expect(json_response['helpful_count']).to eq(0)
      expect(json_response['not_helpful_count']).to eq(0)
      expect(json_response['current_vote']).to be_nil
    end
  end
end
