module Spree
  module Api
    module V3
      module Store
        class ReviewEligibilitiesController < Store::BaseController
          include Spree::Api::V3::Store::ReviewProductLookup

          # GET /api/v3/store/products/:product_id/reviews/eligibility
          def show
            eligibility = Spree::ReviewEligibility.new(
              product: @product,
              store: current_store,
              user: current_user,
              variant: review_variant
            )

            render json: {
              product_id: @product.prefixed_id,
              variant_id: review_variant&.prefixed_id,
              can_review: eligibility.can_review?,
              reason: eligibility.reason,
              verified_purchase: eligibility.verified_purchase?,
              already_reviewed: eligibility.already_reviewed?,
              review_id: eligibility.existing_review&.prefixed_id,
              eligible_order_id: eligibility.eligible_order&.prefixed_id
            }
          end

          private

          def review_variant
            return @review_variant if defined?(@review_variant)

            variant_id = params[:variant_id].presence
            @review_variant = variant_id.present? ? find_product_variant!(variant_id) : nil
          end

          def find_product_variant!(variant_id)
            scope = Spree::Variant.where(product_id: @product.id)

            if Spree::PrefixedId.prefixed_id?(variant_id)
              scope.find_by_prefix_id!(variant_id)
            else
              scope.find(variant_id)
            end
          end
        end
      end
    end
  end
end
