class FixReviewUniquenessOnMysql < ActiveRecord::Migration[7.2]
  def up
    return if connection.supports_partial_index?

    # MySQL ignores a partial index's WHERE clause. Use a generated key so only
    # product-level reviews participate in this uniqueness constraint.
    remove_index :spree_reviews, name: 'idx_spree_reviews_unique_order_product'
    execute <<~SQL
      ALTER TABLE spree_reviews
      ADD COLUMN product_level_review_key TINYINT
      GENERATED ALWAYS AS (CASE WHEN variant_id IS NULL THEN 1 ELSE NULL END) STORED
    SQL
    add_index :spree_reviews, [:store_id, :order_id, :product_id, :customer_id, :product_level_review_key],
              unique: true, name: 'idx_spree_reviews_unique_order_product'
  end

  def down
    return if connection.supports_partial_index?

    raise ActiveRecord::IrreversibleMigration,
          'Restoring the old index would reject valid reviews for different variants'
  end
end
