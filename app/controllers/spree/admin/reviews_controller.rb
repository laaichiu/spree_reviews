module Spree
  module Admin
    class ReviewsController < ResourceController
      include Spree::Admin::ProductsBreadcrumbConcern

      add_breadcrumb 'Reviews', :admin_reviews_path

      before_action :add_review_breadcrumb, only: [:show, :update, :approve, :reject, :destroy]

      def show; end

      def approve
        @review.approve!
        flash[:success] = 'Review approved'

        redirect_to spree.admin_review_path(@review), status: :see_other
      end

      def reject
        @review.reject!
        flash[:success] = 'Review rejected'

        redirect_to spree.admin_review_path(@review), status: :see_other
      end

      protected

      def collection_includes
        [:product, :variant, :order, :store, :user, :answers, review_media: { attachment_attachment: :blob }]
      end

      def collection_default_sort
        'created_at desc'
      end

      def permitted_resource_params
        params.require(:review).permit(
          :rating, :title, :body, :status, :verified_purchase,
          :reviewer_name, :locale, :ip_address,
          metadata: {}, public_metadata: {}, private_metadata: {}
        )
      end

      private

      def add_review_breadcrumb
        add_breadcrumb @review.title, spree.admin_review_path(@review) if @review&.persisted?
      end
    end
  end
end
