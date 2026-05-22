module Spree
  class Review < Spree.base_class
    has_prefix_id :rev

    include Spree::Metadata

    STATUSES = %w[pending approved rejected].freeze

    attribute :status, :string, default: -> { SpreeReviews::Config[:auto_approve_reviews] ? 'approved' : 'pending' }
    attribute :verified_purchase, :boolean, default: false
    attribute :helpful_count, :integer, default: 0
    attribute :not_helpful_count, :integer, default: 0

    belongs_to :product, class_name: 'Spree::Product', inverse_of: :reviews, touch: true
    belongs_to :store, class_name: 'Spree::Store'
    belongs_to :user, class_name: Spree.user_class.to_s, optional: true

    has_many :review_media, class_name: 'Spree::ReviewMedia', dependent: :destroy, inverse_of: :review
    has_many :answers, class_name: 'Spree::ReviewAnswer', dependent: :destroy, inverse_of: :review
    has_many :votes, class_name: 'Spree::ReviewVote', dependent: :destroy, inverse_of: :review

    accepts_nested_attributes_for :review_media, allow_destroy: true
    accepts_nested_attributes_for :answers, allow_destroy: true

    validates :product, :store, :title, :body, presence: true
    validates :status, presence: true, inclusion: { in: STATUSES }
    validates :verified_purchase, inclusion: { in: [true, false] }
    validates :rating, numericality: {
      only_integer: true,
      greater_than_or_equal_to: 1,
      less_than_or_equal_to: 5
    }
    validate :product_belongs_to_store
    validate :review_media_count_within_limit

    scope :approved, -> { where(status: 'approved') }
    scope :pending, -> { where(status: 'pending') }
    scope :rejected, -> { where(status: 'rejected') }
    scope :for_store, ->(store) { where(store: store) }
    scope :for_product, ->(product) { where(product: product) }
    scope :with_rating, ->(ratings) { where(rating: Array(ratings).map(&:to_i).select { |rating| rating.between?(1, 5) }) }
    scope :with_images, -> { joins(:review_media).distinct }
    scope :verified_purchase, -> { where(verified_purchase: true) }
    scope :recent_first, -> { order(created_at: :desc, id: :desc) }
    scope :highest_rating_first, -> { order(rating: :desc, created_at: :desc, id: :desc) }
    scope :lowest_rating_first, -> { order(rating: :asc, created_at: :desc, id: :desc) }

    after_commit :recalculate_product_review_summary

    def self.with_answer(question_key:, values:)
      values = Array(values).reject(&:blank?)
      return none if question_key.blank? || values.empty?

      joins(answers: [:question, :option])
        .where(spree_review_questions: { key: question_key })
        .where(spree_review_question_options: { value: values })
        .distinct
    end

    def approve!
      update!(status: 'approved')
    end

    def reject!
      update!(status: 'rejected')
    end

    def reviewer_display_name
      reviewer_name.presence || user_display_name || Spree.t(:anonymous)
    end

    def recalculate_vote_counts!
      update_columns(
        helpful_count: votes.helpful.count,
        not_helpful_count: votes.not_helpful.count,
        updated_at: Time.current
      )
    end

    private

    def user_display_name
      return if user.blank?

      if user.respond_to?(:name) && user.name.present?
        user.name
      elsif user.respond_to?(:first_name) && user.first_name.present?
        [user.first_name, user.last_name].compact_blank.join(' ')
      end
    end

    def product_belongs_to_store
      return if product.blank? || store.blank?
      return if product.stores.exists?(id: store.id)

      errors.add(:product, :invalid)
    end

    def review_media_count_within_limit
      max_images = SpreeReviews::Config[:max_images_per_review].to_i
      return if max_images <= 0

      kept_media = review_media.reject(&:marked_for_destruction?)
      errors.add(:review_media, :too_long, count: max_images) if kept_media.size > max_images
    end

    def recalculate_product_review_summary
      return if product_id.blank? || store_id.blank?

      Spree::ProductReviewSummary.recalculate!(product_id: product_id, store_id: store_id)
    end
  end
end
