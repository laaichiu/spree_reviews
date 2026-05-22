module Spree
  module Api
    module V3
      class ReviewSerializer < BaseSerializer
        typelize product_id: :string,
                 variant_id: [:string, nullable: true],
                 rating: :number,
                 title: :string,
                 body: :string,
                 status: :string,
                 verified_purchase: :boolean,
                 reviewer_name: [:string, nullable: true],
                 reviewer_display_name: :string,
                 locale: [:string, nullable: true],
                 helpful_count: :number,
                 not_helpful_count: :number,
                 created_at: :string,
                 media: ['ReviewMedia', multi: true],
                 answers: ['ReviewAnswer', multi: true]

        attributes :rating, :title, :body, :status, :verified_purchase,
                   :reviewer_name, :locale, :helpful_count, :not_helpful_count,
                   created_at: :iso8601, updated_at: :iso8601

        attribute :product_id do |review|
          review.product.prefixed_id
        end

        attribute :variant_id do |review|
          review.variant&.prefixed_id
        end

        attribute :reviewer_display_name do |review|
          review.reviewer_display_name
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
