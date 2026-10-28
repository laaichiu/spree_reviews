require 'spec_helper'
require 'spree/api/testing_support/v3/base'

RSpec.describe Spree::Api::V3::Store::ReviewQuestionsController, type: :controller do
  render_views
  routes { Spree::Core::Engine.routes }

  include_context 'API v3 Store'

  let(:product) { create(:product, store: store) }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  describe 'GET #index' do
    it 'returns active store, product, and category scoped questions for the product' do
      category = create(:category, store: store)
      product.categories << category
      store_question = create(:review_question, store: store, label: 'Body Type', position: 1)
      product_question = create(:review_question, :for_product, store: store, product: product, label: 'Usual Size', position: 2)
      category_question = create(:review_question, :for_category, store: store, category: category, label: 'Overall Fit', position: 3)
      create(:review_question, :text, store: store, label: 'Internal note', active: false)

      get :index, params: { product_id: product.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |question| question['id'] }).to eq([
        store_question.prefixed_id,
        product_question.prefixed_id,
        category_question.prefixed_id
      ])
    end

    it 'returns category questions configured on a parent category' do
      parent_taxon = create(:category, store: store)
      child_taxon = create(:category, store: store, parent: parent_taxon)
      product.categories << child_taxon
      category_question = create(:review_question, :for_category, store: store, category: parent_taxon, label: 'Overall Fit')

      get :index, params: { product_id: product.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |question| question['id'] }).to include(category_question.prefixed_id)
    end
  end
end
