module Spree
  module Api
    module V3
      module Store
        class ReviewSummariesController < Store::BaseController
          before_action :set_product

          # GET /api/v3/store/products/:product_id/reviews/summary
          def show
            summary = Spree::ProductReviewSummary.find_or_initialize_by(
              product: @product,
              store: current_store
            )

            render json: Spree::Api::V3::ProductReviewSummarySerializer.new(summary, params: serializer_params).to_h
          end

          private

          def set_product
            @product = product_scope.then do |scope|
              if params[:product_id].to_s.start_with?('prod_')
                scope.find_by_prefix_id!(params[:product_id])
              else
                scope.i18n.find_by!(slug: params[:product_id])
              end
            end
          end

          def product_scope
            Spree::Product.for_store(current_store).active(current_currency)
          end
        end
      end
    end
  end
end
