module Spree
  module Api
    module V3
      module Store
        module ReviewProductLookup
          extend ActiveSupport::Concern

          included do
            before_action :set_product
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
