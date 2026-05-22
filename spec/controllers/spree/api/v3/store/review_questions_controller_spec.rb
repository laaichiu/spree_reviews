require 'spec_helper'
require 'spree/api/testing_support/v3/base'

RSpec.describe Spree::Api::V3::Store::ReviewQuestionsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let(:product) { create(:product, stores: [store]) }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  describe 'GET #index' do
    it 'returns active store, product, and category scoped questions for the product' do
      taxon = create(:taxon, taxonomy: create(:taxonomy, store: store))
      product.taxons << taxon
      store_question = create(:review_question, store: store, label: 'Body Type', position: 1)
      product_question = create(:review_question, :for_product, store: store, product: product, label: 'Usual Size', position: 2)
      category_question = create(:review_question, :for_category, store: store, category: taxon, label: 'Overall Fit', position: 3)
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
      taxonomy = create(:taxonomy, store: store)
      parent_taxon = create(:taxon, taxonomy: taxonomy)
      child_taxon = create(:taxon, taxonomy: taxonomy, parent: parent_taxon)
      product.taxons << child_taxon
      category_question = create(:review_question, :for_category, store: store, category: parent_taxon, label: 'Overall Fit')

      get :index, params: { product_id: product.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |question| question['id'] }).to include(category_question.prefixed_id)
    end
  end
end
