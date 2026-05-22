require 'spec_helper'

RSpec.describe Spree::ReviewQuestion, type: :model do
  let(:store) { create(:store) }
  let(:product) { create(:product, stores: [store]) }

  describe 'validations' do
    it 'requires a product target for product-scoped questions' do
      question = build(:review_question, store: store, applies_to: 'product', product: nil)

      expect(question).not_to be_valid
      expect(question.errors[:product]).to be_present
    end

    it 'rejects product targets on store-scoped questions' do
      question = build(:review_question, store: store, applies_to: 'store', product: product)

      expect(question).not_to be_valid
      expect(question.errors[:product]).to be_present
    end
  end

  describe '.for_product' do
    it 'returns active store, product, and category scoped questions for the product' do
      taxon = create(:taxon, taxonomy: create(:taxonomy, store: store))
      product.taxons << taxon

      store_question = create(:review_question, store: store, applies_to: 'store')
      product_question = create(:review_question, :for_product, store: store, product: product)
      category_question = create(:review_question, :for_category, store: store, category: taxon)
      create(:review_question, store: store, applies_to: 'store', active: false)
      create(:review_question, store: create(:store), applies_to: 'store')

      expect(described_class.for_product(product, store: store)).to contain_exactly(
        store_question,
        product_question,
        category_question
      )
    end

    it 'returns category questions configured on an ancestor category' do
      taxonomy = create(:taxonomy, store: store)
      parent_taxon = create(:taxon, taxonomy: taxonomy)
      child_taxon = create(:taxon, taxonomy: taxonomy, parent: parent_taxon)
      product.taxons << child_taxon
      ancestor_question = create(:review_question, :for_category, store: store, category: parent_taxon)

      expect(described_class.for_product(product, store: store)).to include(ancestor_question)
    end
  end
end
