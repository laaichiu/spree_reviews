class RenameReviewCustomerReferences < ActiveRecord::Migration[7.2]
  def up
    remove_review_uniqueness_indexes
    rename_column :spree_reviews, :user_id, :customer_id
    rename_column :spree_review_votes, :user_id, :customer_id
    add_review_uniqueness_indexes(:customer_id)
  end

  def down
    remove_review_uniqueness_indexes
    rename_column :spree_reviews, :customer_id, :user_id
    rename_column :spree_review_votes, :customer_id, :user_id
    add_review_uniqueness_indexes(:user_id)
  end

  private

  def remove_review_uniqueness_indexes
    remove_index :spree_reviews, name: 'idx_spree_reviews_unique_order_variant'
    remove_index :spree_reviews, name: 'idx_spree_reviews_unique_order_product'
  end

  def add_review_uniqueness_indexes(identity_column)
    add_index :spree_reviews, [:store_id, :order_id, :product_id, :variant_id, identity_column],
              unique: true,
              where: "order_id IS NOT NULL AND #{identity_column} IS NOT NULL AND variant_id IS NOT NULL",
              name: 'idx_spree_reviews_unique_order_variant'
    add_index :spree_reviews, [:store_id, :order_id, :product_id, identity_column],
              unique: true,
              where: "order_id IS NOT NULL AND #{identity_column} IS NOT NULL AND variant_id IS NULL",
              name: 'idx_spree_reviews_unique_order_product'
  end
end
