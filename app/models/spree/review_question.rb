module Spree
  class ReviewQuestion < Spree.base_class
    has_prefix_id :revq

    KINDS = %w[single_select multi_select scale boolean text].freeze
    APPLIES_TO = %w[store category product].freeze

    attribute :filterable, :boolean, default: true
    attribute :required, :boolean, default: false
    attribute :active, :boolean, default: true
    attribute :position, :integer, default: 0

    belongs_to :store, class_name: 'Spree::Store'
    belongs_to :product, class_name: 'Spree::Product', optional: true
    belongs_to :category, class_name: 'Spree::Taxon', optional: true

    has_many :options, -> { order(:position) }, class_name: 'Spree::ReviewQuestionOption',
             dependent: :destroy, inverse_of: :question
    has_many :answers, class_name: 'Spree::ReviewAnswer', dependent: :destroy, inverse_of: :question

    accepts_nested_attributes_for :options, allow_destroy: true

    validates :store, :key, :label, :kind, :applies_to, presence: true
    validates :key, uniqueness: { scope: :store_id }
    validates :kind, inclusion: { in: KINDS }
    validates :applies_to, inclusion: { in: APPLIES_TO }
    validates :filterable, :required, :active, inclusion: { in: [true, false] }
    validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validate :target_matches_applies_to

    scope :active, -> { where(active: true) }
    scope :filterable, -> { where(filterable: true) }
    scope :for_store, ->(store) { where(store: store) }
    scope :ordered, -> { order(:position, :id) }

    def self.for_product(product, store:)
      category_ids = product.taxons.joins(:taxonomy).where(spree_taxonomies: { store_id: store.id }).select(:id)

      where(store: store, applies_to: 'store')
        .or(where(store: store, applies_to: 'product', product: product))
        .or(where(store: store, applies_to: 'category', category_id: category_ids))
        .active
        .ordered
    end

    def option_based?
      kind.in?(%w[single_select multi_select])
    end

    private

    def target_matches_applies_to
      case applies_to
      when 'store'
        errors.add(:product, :present) if product_id.present?
        errors.add(:category, :present) if category_id.present?
      when 'product'
        errors.add(:product, :blank) if product_id.blank?
        errors.add(:category, :present) if category_id.present?
      when 'category'
        errors.add(:category, :blank) if category_id.blank?
        errors.add(:product, :present) if product_id.present?
      end
    end
  end
end
