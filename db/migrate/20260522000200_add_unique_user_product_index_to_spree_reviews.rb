class AddUniqueUserProductIndexToSpreeReviews < ActiveRecord::Migration[7.2]
  def change
    add_index :spree_reviews, [:store_id, :product_id, :user_id],
              unique: true,
              name: 'idx_spree_reviews_unique_user_product'
  end
end
