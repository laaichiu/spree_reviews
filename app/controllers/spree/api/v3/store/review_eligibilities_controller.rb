module Spree
  module Api
    module V3
      module Store
        class ReviewEligibilitiesController < Store::BaseController
          include Spree::Api::V3::Store::ReviewProductLookup

          # GET /api/v3/store/products/:product_id/reviews/eligibility
          def show
            eligibility = Spree::ReviewEligibility.new(product: @product, store: current_store, user: current_user)

            render json: {
              product_id: @product.prefixed_id,
              can_review: eligibility.can_review?,
              reason: eligibility.reason,
              verified_purchase: eligibility.verified_purchase?,
              already_reviewed: eligibility.already_reviewed?,
              review_id: eligibility.existing_review&.prefixed_id,
              eligible_order_id: eligibility.eligible_order&.prefixed_id
            }
          end
        end
      end
    end
  end
end
