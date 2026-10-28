class RenameReviewPrivateMetadata < ActiveRecord::Migration[7.2]
  def up
    if column_exists?(:spree_reviews, :private_metadata)
      if column_exists?(:spree_reviews, :metadata)
        raise ActiveRecord::MigrationError, 'Review metadata and private_metadata both exist; reconcile them before migrating'
      end

      rename_column :spree_reviews, :private_metadata, :metadata
    elsif !column_exists?(:spree_reviews, :metadata)
      raise ActiveRecord::MigrationError, 'Review metadata column is missing'
    end

    # Spree's own metadata migration may already have merged and removed this column.
    add_column :spree_reviews, :public_metadata, :json unless column_exists?(:spree_reviews, :public_metadata)
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Review metadata may have already been consolidated by Spree'
  end
end
