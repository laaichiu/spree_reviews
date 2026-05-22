module Spree
  module Api
    module V3
      module Store
        class ReviewSummariesController < Store::BaseController
          include Spree::Api::V3::Store::ReviewProductLookup

          # GET /api/v3/store/products/:product_id/reviews/summary
          def show
            summary = Spree::ProductReviewSummary.find_or_initialize_by(
              product: @product,
              store: current_store
            )

            render json: Spree::Api::V3::ProductReviewSummarySerializer.new(summary, params: serializer_params).to_h
          end

        end
      end
    end
  end
end
