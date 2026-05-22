class AddVariantToSpreeReviews < ActiveRecord::Migration[7.2]
  def change
    add_reference :spree_reviews, :variant, index: false

    remove_index :spree_reviews, name: 'idx_spree_reviews_unique_user_product', if_exists: true

    add_index :spree_reviews, [:store_id, :product_id, :variant_id, :user_id],
              unique: true,
              where: 'user_id IS NOT NULL AND variant_id IS NOT NULL',
              name: 'idx_spree_reviews_unique_user_variant'
    add_index :spree_reviews, [:store_id, :product_id, :user_id],
              unique: true,
              where: 'user_id IS NOT NULL AND variant_id IS NULL',
              name: 'idx_spree_reviews_unique_user_product'
    add_index :spree_reviews, :variant_id, name: 'idx_spree_reviews_variant_id'
  end
end
