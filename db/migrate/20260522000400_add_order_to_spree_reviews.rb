class AddOrderToSpreeReviews < ActiveRecord::Migration[7.2]
  def up
    add_reference :spree_reviews, :order, index: false

    remove_index :spree_reviews, name: 'idx_spree_reviews_unique_user_variant', if_exists: true
    remove_index :spree_reviews, name: 'idx_spree_reviews_unique_user_product', if_exists: true

    add_index :spree_reviews, [:store_id, :order_id, :product_id, :variant_id, :user_id],
              unique: true,
              where: 'order_id IS NOT NULL AND user_id IS NOT NULL AND variant_id IS NOT NULL',
              name: 'idx_spree_reviews_unique_order_variant'
    add_index :spree_reviews, [:store_id, :order_id, :product_id, :user_id],
              unique: true,
              where: 'order_id IS NOT NULL AND user_id IS NOT NULL AND variant_id IS NULL',
              name: 'idx_spree_reviews_unique_order_product'
    add_index :spree_reviews, :order_id, name: 'idx_spree_reviews_order_id'
  end

  def down
    remove_index :spree_reviews, name: 'idx_spree_reviews_order_id', if_exists: true
    remove_index :spree_reviews, name: 'idx_spree_reviews_unique_order_product', if_exists: true
    remove_index :spree_reviews, name: 'idx_spree_reviews_unique_order_variant', if_exists: true

    add_index :spree_reviews, [:store_id, :product_id, :variant_id, :user_id],
              unique: true,
              where: 'user_id IS NOT NULL AND variant_id IS NOT NULL',
              name: 'idx_spree_reviews_unique_user_variant'
    add_index :spree_reviews, [:store_id, :product_id, :user_id],
              unique: true,
              where: 'user_id IS NOT NULL AND variant_id IS NULL',
              name: 'idx_spree_reviews_unique_user_product'

    remove_reference :spree_reviews, :order, index: false
  end
end
