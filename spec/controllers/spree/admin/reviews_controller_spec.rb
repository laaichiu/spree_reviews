require 'spec_helper'

RSpec.describe Spree::Admin::ReviewsController, type: :controller do
  stub_authorization!
  render_views

  let(:store) { @default_store }
  let(:product) { create(:product, stores: [store]) }
  let(:review_user) { create(:user, first_name: 'Jacqueline', last_name: 'Brown') }
  let!(:review_order) do
    create(:shipped_order, user: review_user, store: store, variants: [product.master]).tap do |order|
      order.update!(shipment_state: 'shipped')
    end
  end
  let!(:review) do
    create(
      :review,
      product: product,
      store: store,
      user: review_user,
      order: review_order,
      title: 'Needs review',
      body: 'Soft fabric and clean stitching.',
      reviewer_name: 'Old Public Name',
      helpful_count: 2,
      not_helpful_count: 1
    )
  end

  describe 'GET #index' do
    it 'renders current-store reviews' do
      create(:review, store: create(:store), title: 'Other store review')

      get :index

      expect(response).to be_successful
      expect(assigns(:collection)).to contain_exactly(review)
      expect(response.body).to include('Needs review')
      expect(response.body).to include('Jacqueline Brown')
      expect(response.body).to include('Customer')
      expect(response.body).to include(review_order.number)
      expect(response.body).to include(edit_admin_order_path(review_order))
      expect(response.body).not_to include('Other store review')
    end
  end

  describe 'GET #show' do
    it 'renders moderation details, answers, and media' do
      question = create(:review_question, store: store, key: 'overall_fit', label: 'Overall fit')
      option = create(:review_question_option, question: question, value: 'true_to_size', label: 'True to size')
      create(:review_answer, review: review, question: question, option: option)
      create(:review_media, review: review, alt: 'Fit photo')

      get :show, params: { id: review.to_param }

      expect(response).to be_successful
      expect(response.body).to include('Needs review')
      expect(response.body).to include('Soft fabric and clean stitching.')
      expect(response.body).to include('Jacqueline Brown')
      expect(response.body).to include(admin_user_path(review_user))
      expect(response.body).to include('Customer')
      expect(response.body).to include('Order')
      expect(response.body).to include(review_order.number)
      expect(response.body).to include(edit_admin_order_path(review_order))
      expect(response.body).to include('Overall fit')
      expect(response.body).to include('True to size')
      expect(response.body).to include('Images')
      expect(response.body).to include('Fit photo')
    end

    it 'reflects customer profile name changes in the reviewer detail' do
      review_user.update!(first_name: 'Solomia', last_name: 'Smith')

      get :show, params: { id: review.to_param }

      expect(response).to be_successful
      expect(response.body).to include('Solomia Smith')
      expect(response.body).not_to include('Jacqueline Brown')
    end
  end

  describe 'PUT #approve' do
    it 'approves a review' do
      put :approve, params: { id: review.to_param }

      expect(review.reload.status).to eq('approved')
      expect(flash[:success]).to eq('Review approved')
      expect(response).to redirect_to(admin_review_path(review))
    end
  end

  describe 'PUT #reject' do
    it 'rejects a review' do
      put :reject, params: { id: review.to_param }

      expect(review.reload.status).to eq('rejected')
      expect(flash[:success]).to eq('Review rejected')
      expect(response).to redirect_to(admin_review_path(review))
    end
  end

  describe 'DELETE #destroy' do
    it 'deletes a review' do
      expect {
        delete :destroy, params: { id: review.to_param }
      }.to change(Spree::Review, :count).by(-1)

      expect(response).to redirect_to(admin_reviews_path)
    end
  end
end
