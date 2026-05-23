module Spree
  module Api
    module V3
      module Store
        class ReviewSummariesController < Store::BaseController
          include Spree::Api::V3::Store::ReviewProductLookup

          # GET /api/v3/store/products/:product_id/reviews/summary
          def show
            summary = if truthy_param?(params[:verified_purchase])
                        filtered_summary
                      else
                        Spree::ProductReviewSummary.find_or_initialize_by(
                          product: @product,
                          store: current_store
                        )
                      end

            render json: Spree::Api::V3::ProductReviewSummarySerializer.new(summary, params: serializer_params).to_h
          end

          private

          def filtered_summary
            counts = @product.reviews.approved.for_store(current_store).verified_purchase.group(:rating).count
            reviews_count = counts.values.sum
            weighted_total = counts.sum { |rating, count| rating.to_i * count }

            Spree::ProductReviewSummary.new(
              product: @product,
              store: current_store,
              reviews_count: reviews_count,
              average_rating: reviews_count.positive? ? (weighted_total.to_d / reviews_count).round(2) : 0,
              rating_1_count: counts.fetch(1, 0),
              rating_2_count: counts.fetch(2, 0),
              rating_3_count: counts.fetch(3, 0),
              rating_4_count: counts.fetch(4, 0),
              rating_5_count: counts.fetch(5, 0)
            )
          end

          def truthy_param?(value)
            ActiveModel::Type::Boolean.new.cast(value)
          end
        end
      end
    end
  end
end
