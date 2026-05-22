module Spree
  module Api
    module V3
      module Store
        class ReviewVotesController < Store::BaseController
          before_action :set_review

          # POST /api/v3/store/reviews/:review_id/helpful_votes
          def create
            vote = existing_vote || @review.votes.build
            vote.assign_attributes(vote_params)
            vote.user = current_user if current_user
            vote.ip_address ||= request.remote_ip if current_user.blank?

            if vote.save
              render json: Spree::Api::V3::ReviewSerializer.new(@review.reload, params: serializer_params).to_h, status: :created
            else
              render_validation_error(vote.errors)
            end
          end

          private

          def set_review
            @review = Spree::Review.approved.for_store(current_store).find_by_prefix_id!(params[:review_id])
          end

          def vote_params
            permitted = params.permit(:vote).to_h
            permitted[:vote] = 'helpful' if permitted[:vote].blank?
            permitted
          end

          def existing_vote
            return @review.votes.find_by(user: current_user) if current_user

            @review.votes.find_by(ip_address: request.remote_ip)
          end
        end
      end
    end
  end
end
