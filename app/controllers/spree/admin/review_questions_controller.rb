module Spree
  module Admin
    class ReviewQuestionsController < ResourceController
      include Spree::Admin::ProductsBreadcrumbConcern

      add_breadcrumb 'Review questions', :admin_review_questions_path

      before_action :load_form_collections, only: [:new, :edit, :create, :update]
      before_action :add_question_breadcrumb, only: [:edit, :update, :destroy]

      protected

      def collection_includes
        [:product, :category, :options]
      end

      def collection_default_sort
        'position asc'
      end

      def permitted_resource_params
        params.require(:review_question).permit(
          :key, :label, :kind, :applies_to,
          :filterable, :required, :active, :position,
          :product_id, :category_id,
          options_attributes: [
            :id, :value, :label, :active, :position, :_destroy
          ]
        )
      end

      private

      def load_form_collections
        @products = Spree::Product.for_store(current_store).order(:id)
        @categories = Spree::Taxon.joins(:taxonomy).
                      where(spree_taxonomies: { store_id: current_store.id }).
                      order(:lft, :id)
      end

      def add_question_breadcrumb
        add_breadcrumb @review_question.label, spree.edit_admin_review_question_path(@review_question) if @review_question&.persisted?
      end
    end
  end
end
