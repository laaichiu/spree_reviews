module Spree
  module Api
    module V3
      module Admin
        class ReviewsController < ResourceController
          scoped_resource :reviews

          # POST /api/v3/admin/reviews/:id/approve
          def approve
            @resource = find_resource
            authorize_resource!(@resource, :update)
            @resource.approve!

            render json: serialize_resource(@resource)
          end

          # POST /api/v3/admin/reviews/:id/reject
          def reject
            @resource = find_resource
            authorize_resource!(@resource, :update)
            @resource.reject!

            render json: serialize_resource(@resource)
          end

          protected

          def model_class
            Spree::Review
          end

          def serializer_class
            Spree::Api::V3::Admin::ReviewSerializer
          end

          def scope_includes
            [
              :product,
              :variant,
              :order,
              :store,
              :user,
              review_media: { attachment_attachment: :blob },
              answers: [:question, :option]
            ]
          end

          def apply_collection_sort(collection)
            return collection if params[:sort].present?

            collection.recent_first
          end

          def permitted_params
            normalized = normalize_params(
              params.permit(
                :rating, :title, :body, :status,
                :reviewer_name, :locale, :ip_address,
                metadata: {}, public_metadata: {},
                review_media: [
                  :id, :alt, :position, :_destroy
                ],
                answers: [
                  :id, :question_id, :option_id,
                  :value_text, :value_number, :value_boolean, :_destroy
                ]
              )
            )

            decode_nested_ids(normalized, :review_media_attributes)
            decode_nested_ids(normalized, :answers_attributes)
            normalized
          end

          private

          def decode_nested_ids(params_hash, key)
            Array(params_hash[key]).each do |attributes|
              id = attributes[:id]
              next unless Spree::PrefixedId.prefixed_id?(id)

              attributes[:id] = Spree::PrefixedId.decode_prefixed_id(id)
            end
          end
        end
      end
    end
  end
end
