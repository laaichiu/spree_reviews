module Spree
  class ReviewMedia < Spree.base_class
    self.table_name = 'spree_review_media'

    has_prefix_id :rmedia

    IMAGE_CONTENT_TYPES = %w[
      image/avif
      image/jpeg
      image/png
      image/webp
    ].freeze

    attribute :position, :integer, default: 0

    belongs_to :review, class_name: 'Spree::Review', inverse_of: :review_media, touch: true
    has_one_attached :attachment, service: Spree.public_storage_service_name

    acts_as_list scope: :review

    validates :review, presence: true
    validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :attachment, attached: true, content_type: IMAGE_CONTENT_TYPES
    validate :attachment_size_within_limit
    validate :review_media_count_within_limit, on: :create

    private

    def attachment_size_within_limit
      return unless attachment.attached?

      max_size = SpreeReviews::Config[:max_image_size_megabytes].to_i.megabytes
      return if max_size <= 0
      return if attachment.blob.byte_size <= max_size

      errors.add(:attachment, :too_large, count: ActiveSupport::NumberHelper.number_to_human_size(max_size))
    end

    def review_media_count_within_limit
      return if review.blank? || !review.persisted?

      max_images = SpreeReviews::Config[:max_images_per_review].to_i
      return if max_images <= 0
      return if review.review_media.where.not(id: id).count < max_images

      errors.add(:review, :too_long, count: max_images)
    end
  end
end
