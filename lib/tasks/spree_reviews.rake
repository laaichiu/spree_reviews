namespace :spree_reviews do
  desc 'Backfill legacy review order and variant links from shipped purchases'
  task backfill_review_purchase_links: :environment do
    dry_run = ActiveModel::Type::Boolean.new.cast(ENV.fetch('DRY_RUN', false))
    updated_count = 0
    skipped_count = 0

    Spree::ReviewPurchaseAttribution.backfill_scope.find_each do |review|
      if dry_run
        target = Spree::ReviewPurchaseAttribution.new(review).target
        target.present? ? updated_count += 1 : skipped_count += 1
        next
      end

      Spree::ReviewPurchaseAttribution.new(review).call ? updated_count += 1 : skipped_count += 1
    end

    action = dry_run ? 'would update' : 'updated'
    puts "spree_reviews:backfill_review_purchase_links #{action} #{updated_count} reviews, skipped #{skipped_count} reviews"
  end
end
