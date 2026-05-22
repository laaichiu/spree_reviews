require 'spec_helper'
require 'spree/api/testing_support/v3/base'

RSpec.describe Spree::Api::V3::Store::ReviewsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let(:product) { create(:product, stores: [store]) }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  describe 'GET #index' do
    let(:fit_question) { create(:review_question, store: store, key: 'overall_fit') }
    let(:true_to_size) { create(:review_question_option, question: fit_question, value: 'true_to_size', label: 'True to size') }
    let(:runs_small) { create(:review_question_option, question: fit_question, value: 'runs_small', label: 'Runs small') }
    let!(:matching_review) { create(:review, :approved, product: product, store: store, rating: 5) }
    let!(:other_review) { create(:review, :approved, product: product, store: store, rating: 3) }

    before do
      create(:review_answer, review: matching_review, question: fit_question, option: true_to_size)
      create(:review_answer, review: other_review, question: fit_question, option: runs_small)
      create(:review, product: product, store: store, rating: 1)
    end

    it 'returns approved reviews for the product' do
      get :index, params: { product_id: product.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |review| review['id'] }).to contain_exactly(
        matching_review.prefixed_id,
        other_review.prefixed_id
      )
      expect(json_response['meta']['count']).to eq(2)
    end

    it 'filters by rating and configured answer values' do
      get :index, params: {
        product_id: product.prefixed_id,
        rating: 5,
        answers: { overall_fit: 'true_to_size' }
      }

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |review| review['id'] }).to eq([matching_review.prefixed_id])
    end
  end

  describe 'POST #create' do
    let(:fit_question) { create(:review_question, store: store, key: 'overall_fit', required: true) }
    let(:true_to_size) { create(:review_question_option, question: fit_question, value: 'true_to_size', label: 'True to size') }
    let(:blob) do
      ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new('review image'),
        filename: 'review.jpg',
        content_type: 'image/jpeg'
      )
    end

    before do
      request.headers['Authorization'] = "Bearer #{jwt_token}"
      create(:shipped_order, user: user, store: store, variants: [product.master]).update!(shipment_state: 'shipped')
    end

    it 'creates a pending review with answers and images' do
      true_to_size

      expect {
        post :create, params: {
          product_id: product.prefixed_id,
          rating: 5,
          title: 'Love it',
          body: 'The fabric is excellent and the fit is right.',
          reviewer_name: 'Julie M.',
          answers: { overall_fit: 'true_to_size' },
          images: [{ signed_id: blob.signed_id, alt: 'Fit photo' }]
        }
      }.to change(Spree::Review, :count).by(1)

      review = Spree::Review.last
      expect(response).to have_http_status(:created)
      expect(review.status).to eq('pending')
      expect(review.user).to eq(user)
      expect(review.verified_purchase).to be(true)
      expect(review.answers.first.option).to eq(true_to_size)
      expect(review.review_media.first.attachment).to be_attached
      expect(json_response['media'].first['alt']).to eq('Fit photo')
    end

    it 'returns validation errors for missing required answers' do
      fit_question

      post :create, params: {
        product_id: product.prefixed_id,
        rating: 5,
        title: 'Love it',
        body: 'The fabric is excellent.'
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['code']).to eq('validation_error')
      expect(json_response['error']['details']['answers']).to be_present
    end

    it 'requires authentication' do
      request.headers['Authorization'] = nil

      expect {
        post :create, params: {
          product_id: product.prefixed_id,
          rating: 5,
          title: 'Love it',
          body: 'The fabric is excellent.'
        }
      }.not_to change(Spree::Review, :count)

      expect(response).to have_http_status(:unauthorized)
      expect(json_response['error']['code']).to eq('authentication_required')
    end

    it 'rejects customers without a shipped purchase for the product' do
      other_product = create(:product, stores: [store])

      expect {
        post :create, params: {
          product_id: other_product.prefixed_id,
          rating: 5,
          title: 'Love it',
          body: 'The fabric is excellent.'
        }
      }.not_to change(Spree::Review, :count)

      expect(response).to have_http_status(:forbidden)
      expect(json_response['error']['code']).to eq('review_not_allowed')
      expect(json_response['error']['details']['reason']).to eq('not_purchased')
    end

    it 'rejects duplicate customer reviews for the same product' do
      existing_review = create(:review, product: product, store: store, user: user)

      expect {
        post :create, params: {
          product_id: product.prefixed_id,
          rating: 4,
          title: 'Still good',
          body: 'I still like it.'
        }
      }.not_to change(Spree::Review, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['code']).to eq('review_already_exists')
      expect(json_response['error']['details']['reason']).to eq('already_reviewed')
      expect(json_response['error']['details']['review_id']).to eq(existing_review.prefixed_id)
    end
  end
end
