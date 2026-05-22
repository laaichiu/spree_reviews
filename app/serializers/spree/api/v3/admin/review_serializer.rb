module Spree
  module Api
    module V3
      module Admin
        class ReviewSerializer < V3::ReviewSerializer
          typelize store_id: :string,
                   user_id: [:string, nullable: true],
                   order_id: [:string, nullable: true],
                   reviewer_name: [:string, nullable: true],
                   ip_address: [:string, nullable: true],
                   metadata: 'Record<string, unknown>',
                   public_metadata: 'Record<string, unknown>',
                   private_metadata: 'Record<string, unknown>'

          attributes :reviewer_name, :ip_address, :metadata, :public_metadata, :private_metadata,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :store_id do |review|
            review.store.prefixed_id
          end

          attribute :user_id do |review|
            review.user&.prefixed_id
          end

          attribute :order_id do |review|
            review.order&.prefixed_id
          end

          many :review_media,
               key: :media,
               resource: Spree::Api::V3::ReviewMediaSerializer

          many :answers,
               resource: Spree::Api::V3::ReviewAnswerSerializer
        end
      end
    end
  end
end
