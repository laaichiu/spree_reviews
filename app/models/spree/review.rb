module Spree
  class Review < Spree.base_class
    has_prefix_id :rev

    include Spree::Metadata

    STATUSES = %w[pending approved rejected].freeze
    TITLE_MAX_LENGTH = 120
    TITLE_EXCERPT_LENGTH = 80
    BODY_EXCERPT_LENGTH = 100

    attribute :status, :string, default: -> { SpreeReviews::Config[:auto_approve_reviews] ? 'approved' : 'pending' }
    attribute :verified_purchase, :boolean, default: false
    attribute :helpful_count, :integer, default: 0
    attribute :not_helpful_count, :integer, default: 0

    self.whitelisted_ransackable_attributes = %w[
      product_id variant_id order_id store_id user_id rating status verified_purchase
      reviewer_name title body locale helpful_count not_helpful_count
      created_at updated_at
    ]
    self.whitelisted_ransackable_associations = %w[product variant order store user answers review_media votes]

    belongs_to :product, class_name: 'Spree::Product', inverse_of: :reviews, touch: true
    belongs_to :variant, class_name: 'Spree::Variant', optional: true
    belongs_to :order, class_name: 'Spree::Order', optional: true
    belongs_to :store, class_name: 'Spree::Store'
    belongs_to :user, class_name: Spree.customer_class.to_s, optional: true

    has_many :review_media, class_name: 'Spree::ReviewMedia', dependent: :destroy, inverse_of: :review
    has_many :answers, class_name: 'Spree::ReviewAnswer', dependent: :destroy, inverse_of: :review
    has_many :votes, class_name: 'Spree::ReviewVote', dependent: :destroy, inverse_of: :review

    accepts_nested_attributes_for :review_media, allow_destroy: true
    accepts_nested_attributes_for :answers, allow_destroy: true

    before_validation :normalize_optional_text_fields

    validates :product, :store, presence: true
    validates :status, presence: true, inclusion: { in: STATUSES }
    validates :verified_purchase, inclusion: { in: [true, false] }
    validates :title, presence: true, if: :title_required?
    validates :title, length: { maximum: TITLE_MAX_LENGTH }, if: :title_length_validation_required?
    validates :user_id, uniqueness: { scope: [:store_id, :order_id, :product_id, :variant_id], allow_nil: true }
    validates :rating, numericality: {
      only_integer: true,
      greater_than_or_equal_to: 1,
      less_than_or_equal_to: 5
    }
    validate :product_belongs_to_store
    validate :variant_belongs_to_product
    validate :order_belongs_to_store_and_user
    validate :order_contains_reviewed_item
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
      values = Array(values).reject { |value| value.nil? || (value.respond_to?(:empty?) && value.empty?) }
      return none if question_key.blank? || values.empty?

      query = joins(answers: :question).
              left_joins(answers: :option).
              where(spree_review_questions: { key: question_key })
      conditions = []
      bind_values = {}
      text_values = values.map(&:to_s)
      numeric_values = values.filter_map { |value| numeric_filter_value(value) }
      boolean_values = values.map { |value| boolean_filter_value(value) }.reject(&:nil?).uniq

      unless text_values.empty?
        conditions << 'spree_review_question_options.value IN (:text_values)'
        conditions << 'spree_review_answers.value_text IN (:text_values)'
        bind_values[:text_values] = text_values
      end

      unless numeric_values.empty?
        conditions << 'spree_review_answers.value_number IN (:numeric_values)'
        bind_values[:numeric_values] = numeric_values
      end

      unless boolean_values.empty?
        conditions << 'spree_review_answers.value_boolean IN (:boolean_values)'
        bind_values[:boolean_values] = boolean_values
      end

      query.where(conditions.join(' OR '), bind_values).distinct
    end

    def self.numeric_filter_value(value)
      BigDecimal(value.to_s)
    rescue ArgumentError
      nil
    end

    def self.boolean_filter_value(value)
      case value
      when true, false
        value
      else
        {
          'true' => true,
          '1' => true,
          'yes' => true,
          'false' => false,
          '0' => false,
          'no' => false
        }[value.to_s.downcase]
      end
    end

    def approve!
      update!(status: 'approved')
    end

    def reject!
      update!(status: 'rejected')
    end

    def self.public_reviewer_name(name)
      normalized_name = name.to_s.squish
      return if normalized_name.blank?

      name_parts = normalized_name.split(/\s+/)
      public_reviewer_name_from_parts(
        name_parts.first,
        name_parts.length > 1 ? name_parts.last : nil
      )
    end

    def self.public_reviewer_name_from_parts(first_name, last_name = nil)
      normalized_first_name = first_name.to_s.squish.presence
      normalized_last_name = last_name.to_s.squish.presence
      return if normalized_first_name.blank? && normalized_last_name.blank?

      first_name = normalized_first_name
      if first_name.blank? && normalized_last_name.present?
        first_name = "#{normalized_last_name.first.upcase}."
      end
      last_initial = if normalized_first_name.present? && normalized_last_name.present?
                       normalized_last_name.first&.upcase
                     end

      [first_name, last_initial.present? ? "#{last_initial}." : nil].compact.join(' ')
    end

    def self.profile_reviewer_name_from_user(user)
      return if user.blank?

      first_name = user.try(:firstname).presence || user.try(:first_name).presence
      last_name = user.try(:lastname).presence || user.try(:last_name).presence
      full_name = [first_name, last_name].compact_blank.join(' ').presence
      return full_name if full_name.present?

      return user.full_name if user.respond_to?(:full_name) && user.full_name.present?
      if user.respond_to?(:name) && user.name.respond_to?(:full) && user.name.full.present?
        return user.name.full
      end

      user.name if user.respond_to?(:name) && user.name.is_a?(String) && user.name.present?
    end

    def self.admin_reviewer_name_from_user(user)
      profile_reviewer_name_from_user(user) ||
        (user.email.presence if user&.respond_to?(:email))
    end

    def reviewer_display_name
      self.class.public_reviewer_name(
        self.class.profile_reviewer_name_from_user(user) || reviewer_name.presence
      ) ||
        Spree.t(:anonymous)
    end

    def admin_reviewer_name
      self.class.admin_reviewer_name_from_user(user) || reviewer_name.presence || Spree.t(:anonymous)
    end

    def admin_display_name
      title.presence || "Review #{prefixed_id || id || ''}".squish
    end

    def title_excerpt(length: TITLE_EXCERPT_LENGTH)
      admin_display_name.truncate(length)
    end

    def body_excerpt(length: BODY_EXCERPT_LENGTH)
      body_text = body.to_s.squish
      return 'No written review content' if body_text.blank?

      body_text.truncate(length)
    end

    def attributed_order
      order || purchase_attribution_target&.order
    end

    def current_vote_for(user: nil, ip_address: nil)
      if user.present?
        votes.find_by(user: user)&.vote
      elsif ip_address.present?
        votes.find_by(ip_address: ip_address)&.vote
      end
    end

    def recalculate_vote_counts!
      update_columns(
        helpful_count: votes.helpful.count,
        not_helpful_count: votes.not_helpful.count,
        updated_at: Time.current
      )
    end

    private

    def purchase_attribution_target
      return @purchase_attribution_target if defined?(@purchase_attribution_target)

      @purchase_attribution_target = Spree::ReviewPurchaseAttribution.new(self).target
    end

    def normalize_optional_text_fields
      self.title = title.to_s.squish
      self.body = body.to_s.strip
    end

    def title_required?
      new_record? || will_save_change_to_title? || title_in_database.present?
    end

    def title_length_validation_required?
      new_record? || will_save_change_to_title?
    end

    def product_belongs_to_store
      return if product.blank? || store.blank?
      return if Spree::Product.for_store(store).where(id: product.id).exists?

      errors.add(:product, :invalid)
    end

    def variant_belongs_to_product
      return if variant.blank? || product.blank?
      return if variant.product_id == product.id

      errors.add(:variant, :invalid)
    end

    def order_belongs_to_store_and_user
      return if order.blank?

      errors.add(:order, :invalid) if store.present? && order.store_id != store.id
      errors.add(:order, :invalid) if user.present? && order.customer_id != user.id
    end

    def order_contains_reviewed_item
      return if order.blank? || product.blank?
      return unless order_purchase_validation_required?
      return if order_contains_reviewable_purchase?

      errors.add(:order, :invalid)
    end

    def order_purchase_validation_required?
      new_record? ||
        will_save_change_to_order_id? ||
        will_save_change_to_product_id? ||
        will_save_change_to_variant_id?
    end

    def order_contains_reviewable_purchase?
      Spree::ReviewablePurchase.new(order: order, product: product, variant: variant).reviewable?
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
