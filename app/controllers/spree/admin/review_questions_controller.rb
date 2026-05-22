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
                      order(:lft, :id).
                      to_a
        @category_product_counts = category_product_counts(@categories)
        @category_options = @categories.map do |category|
          [category_option_label(category), category.id]
        end
      end

      def category_option_label(category)
        product_count = @category_product_counts.fetch(category.id, 0)

        "#{category_path_label(category)} (#{product_count} #{'product'.pluralize(product_count)})"
      end

      def category_path_label(category)
        (category.pretty_name.presence || category.name).to_s.gsub(' -> ', ' > ')
      end

      def category_product_counts(categories)
        taxons = categories.to_a
        descendant_ids_by_category_id = taxons.to_h do |category|
          [category.id, category.self_and_descendants.ids]
        end
        descendant_ids = descendant_ids_by_category_id.values.flatten.uniq
        product_ids_by_taxon_id = direct_product_ids_by_taxon_id(descendant_ids)

        descendant_ids_by_category_id.transform_values do |ids|
          ids.flat_map { |taxon_id| product_ids_by_taxon_id.fetch(taxon_id, []) }.uniq.size
        end
      end

      def direct_product_ids_by_taxon_id(taxon_ids)
        return {} if taxon_ids.empty?

        Spree::Product.for_store(current_store).
          joins(:taxons).
          where(spree_taxons: { id: taxon_ids }).
          distinct.
          pluck('spree_taxons.id', 'spree_products.id').
          each_with_object(Hash.new { |hash, taxon_id| hash[taxon_id] = [] }) do |(taxon_id, product_id), product_ids|
            product_ids[taxon_id] << product_id
          end
      end

      def add_question_breadcrumb
        add_breadcrumb @review_question.label, spree.edit_admin_review_question_path(@review_question) if @review_question&.persisted?
      end
    end
  end
end
