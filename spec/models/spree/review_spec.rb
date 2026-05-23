require 'spec_helper'

RSpec.describe Spree::Review, type: :model do
  let(:store) { create(:store) }
  let(:product) { create(:product, stores: [store]) }

  describe 'defaults' do
    it 'starts pending with zero vote counters' do
      review = described_class.new(product: product, store: store, rating: 5, title: 'Great', body: 'Loved it')

      expect(review.status).to eq('pending')
      expect(review.verified_purchase).to be(false)
      expect(review.helpful_count).to eq(0)
      expect(review.not_helpful_count).to eq(0)
    end
  end

  describe '#reviewer_display_name' do
    it 'formats full reviewer names as a first name and last initial' do
      review = build(:review, product: product, store: store, reviewer_name: 'Jacqueline Brown')

      expect(review.reviewer_display_name).to eq('Jacqueline B.')
    end

    it 'formats profile name parts without exposing a lone last name' do
      expect(described_class.public_reviewer_name_from_parts('Jacqueline', 'Brown')).
        to eq('Jacqueline B.')
      expect(described_class.public_reviewer_name_from_parts('Jacqueline', nil)).to eq('Jacqueline')
      expect(described_class.public_reviewer_name_from_parts(nil, 'Brown')).to eq('B.')
    end

    it 'uses the current profile name for associated users while keeping public display private' do
      user = create(:user, first_name: 'Jacqueline', last_name: 'Brown')
      review = create(:review, product: product, store: store, user: user, reviewer_name: 'Old Name')

      expect(review.admin_reviewer_name).to eq('Jacqueline Brown')
      expect(review.reviewer_display_name).to eq('Jacqueline B.')

      user.update!(first_name: 'Solomia', last_name: 'Smith')

      expect(review.reload.admin_reviewer_name).to eq('Solomia Smith')
      expect(review.reviewer_display_name).to eq('Solomia S.')
    end
  end

  describe 'validations' do
    it 'accepts ratings from one to five' do
      expect(build(:review, product: product, store: store, rating: 5)).to be_valid
      expect(build(:review, product: product, store: store, rating: 6)).not_to be_valid
    end

    it 'requires the product to belong to the review store' do
      other_store = create(:store)
      review = build(:review, product: product, store: other_store)

      expect(review).not_to be_valid
      expect(review.errors[:product]).to be_present
    end

    it 'allows one review per customer, order, and product variant in a store' do
      user = create(:user)
      variant = create(:reviewable_variant, product: product)
      other_variant = create(:reviewable_variant, product: product)
      order = create(:shipped_order, user: user, store: store, variants: [variant, other_variant])
      repeat_order = create(:shipped_order, user: user, store: store, variants: [variant])
      create(:review, :for_variant, product: product, variant: variant, order: order, store: store, user: user)

      duplicate = build(:review, :for_variant, product: product, variant: variant, order: order, store: store, user: user)
      other_variant_review = build(:review, :for_variant, product: product, variant: other_variant, order: order, store: store, user: user)
      repeat_order_review = build(:review, :for_variant, product: product, variant: variant, order: repeat_order, store: store, user: user)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to be_present
      expect(other_variant_review).to be_valid
      expect(repeat_order_review).to be_valid
    end

    it 'requires the variant to belong to the reviewed product' do
      other_product = create(:product, stores: [store])
      review = build(:review, product: product, variant: other_product.master, store: store)

      expect(review).not_to be_valid
      expect(review.errors[:variant]).to be_present
    end

    it 'requires the order to contain the reviewed variant' do
      user = create(:user)
      variant = create(:reviewable_variant, product: product)
      other_variant = create(:reviewable_variant, product: product)
      order = create(:shipped_order, user: user, store: store, variants: [other_variant])

      review = build(:review, :for_variant, product: product, variant: variant, order: order, store: store, user: user)

      expect(review).not_to be_valid
      expect(review.errors[:order]).to be_present
    end
  end

  describe '.with_answer' do
    it 'filters reviews by configured question option values' do
      question = create(:review_question, store: store, key: 'body_type')
      matching_option = create(:review_question_option, question: question, value: 'curvy')
      other_option = create(:review_question_option, question: question, value: 'straight')
      matching_review = create(:review, :approved, product: product, store: store)
      other_review = create(:review, :approved, product: product, store: store)

      create(:review_answer, review: matching_review, question: question, option: matching_option)
      create(:review_answer, review: other_review, question: question, option: other_option)

      expect(described_class.with_answer(question_key: 'body_type', values: ['curvy'])).to contain_exactly(matching_review)
    end

    it 'filters reviews by boolean and scale answer values' do
      recommend_question = create(:review_question, :boolean, store: store, key: 'recommend')
      fit_scale_question = create(:review_question, :scale, store: store, key: 'fit_score')
      matching_review = create(:review, :approved, product: product, store: store)
      other_review = create(:review, :approved, product: product, store: store)

      create(:review_answer, review: matching_review, question: recommend_question, option: nil, value_boolean: false)
      create(:review_answer, review: other_review, question: recommend_question, option: nil, value_boolean: true)
      create(:review_answer, review: matching_review, question: fit_scale_question, option: nil, value_number: 4)
      create(:review_answer, review: other_review, question: fit_scale_question, option: nil, value_number: 2)

      expect(described_class.with_answer(question_key: 'recommend', values: ['false'])).to contain_exactly(matching_review)
      expect(described_class.with_answer(question_key: 'fit_score', values: ['4'])).to contain_exactly(matching_review)
    end
  end

  describe 'summary recalculation' do
    it 'caches approved review counts and rating distribution' do
      create(:review, :approved, product: product, store: store, rating: 5)
      create(:review, :approved, product: product, store: store, rating: 4)
      create(:review, product: product, store: store, rating: 1)

      summary = Spree::ProductReviewSummary.find_by!(product: product, store: store)

      expect(summary.reviews_count).to eq(2)
      expect(summary.average_rating).to eq(BigDecimal('4.5'))
      expect(summary.rating_distribution).to eq(
        1 => 0,
        2 => 0,
        3 => 0,
        4 => 1,
        5 => 1
      )
    end

    it 'updates the summary when a pending review is approved' do
      review = create(:review, product: product, store: store, rating: 3)
      summary = Spree::ProductReviewSummary.find_by!(product: product, store: store)

      expect(summary.reviews_count).to eq(0)

      review.approve!

      expect(summary.reload.reviews_count).to eq(1)
      expect(summary.average_rating).to eq(BigDecimal('3.0'))
    end
  end
end
