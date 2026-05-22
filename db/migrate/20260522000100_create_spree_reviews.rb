class CreateSpreeReviews < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_reviews do |t|
      t.references :product, null: false, index: false
      t.references :store, null: false, index: false
      t.bigint :user_id
      t.integer :rating, null: false
      t.string :title, null: false
      t.text :body, null: false
      t.string :status, null: false
      t.boolean :verified_purchase, null: false
      t.string :reviewer_name
      t.string :locale
      t.string :ip_address
      t.integer :helpful_count, null: false
      t.integer :not_helpful_count, null: false
      json_column(t, :public_metadata)
      json_column(t, :private_metadata)
      t.timestamps
    end

    add_index :spree_reviews, [:store_id, :product_id, :status], name: 'idx_spree_reviews_public_lookup'
    add_index :spree_reviews, [:product_id, :rating], name: 'idx_spree_reviews_product_rating'
    add_index :spree_reviews, [:product_id, :created_at], name: 'idx_spree_reviews_product_created_at'
    add_index :spree_reviews, :user_id, name: 'idx_spree_reviews_user_id'

    create_table :spree_review_media do |t|
      t.references :review, null: false, index: false
      t.integer :position, null: false
      t.string :alt
      t.timestamps
    end

    add_index :spree_review_media, [:review_id, :position], name: 'idx_spree_review_media_review_position'

    create_table :spree_review_questions do |t|
      t.references :store, null: false, index: false
      t.references :product, index: false
      t.bigint :category_id
      t.string :key, null: false
      t.string :label, null: false
      t.string :kind, null: false
      t.string :applies_to, null: false
      t.boolean :filterable, null: false
      t.boolean :required, null: false
      t.boolean :active, null: false
      t.integer :position, null: false
      t.timestamps
    end

    add_index :spree_review_questions, [:store_id, :key], unique: true, name: 'idx_spree_review_questions_store_key'
    add_index :spree_review_questions, [:store_id, :applies_to, :position], name: 'idx_spree_review_questions_scope'
    add_index :spree_review_questions, :product_id, name: 'idx_spree_review_questions_product_id'
    add_index :spree_review_questions, :category_id, name: 'idx_spree_review_questions_category_id'

    create_table :spree_review_question_options do |t|
      t.references :review_question, null: false, index: false
      t.string :value, null: false
      t.string :label, null: false
      t.boolean :active, null: false
      t.integer :position, null: false
      t.timestamps
    end

    add_index :spree_review_question_options, [:review_question_id, :value], unique: true,
              name: 'idx_spree_review_options_question_value'
    add_index :spree_review_question_options, [:review_question_id, :position],
              name: 'idx_spree_review_options_question_position'

    create_table :spree_review_answers do |t|
      t.references :review, null: false, index: false
      t.references :review_question, null: false, index: false
      t.references :review_question_option, index: false
      t.text :value_text
      t.decimal :value_number, precision: 10, scale: 2
      t.boolean :value_boolean
      t.timestamps
    end

    add_index :spree_review_answers, [:review_id, :review_question_id], name: 'idx_spree_review_answers_review_question'
    add_index :spree_review_answers, :review_question_option_id, name: 'idx_spree_review_answers_option_id'

    create_table :spree_product_review_summaries do |t|
      t.references :product, null: false, index: false
      t.references :store, null: false, index: false
      t.decimal :average_rating, precision: 3, scale: 2, null: false
      t.integer :reviews_count, null: false
      t.integer :rating_1_count, null: false
      t.integer :rating_2_count, null: false
      t.integer :rating_3_count, null: false
      t.integer :rating_4_count, null: false
      t.integer :rating_5_count, null: false
      json_column(t, :summary_data)
      t.timestamps
    end

    add_index :spree_product_review_summaries, [:store_id, :product_id], unique: true,
              name: 'idx_spree_review_summaries_store_product'

    create_table :spree_review_votes do |t|
      t.references :review, null: false, index: false
      t.bigint :user_id
      t.string :ip_address
      t.string :vote, null: false
      t.timestamps
    end

    add_index :spree_review_votes, [:review_id, :user_id], name: 'idx_spree_review_votes_review_user'
    add_index :spree_review_votes, [:review_id, :ip_address], name: 'idx_spree_review_votes_review_ip'
  end

  private

  def json_column(table, name)
    if table.respond_to?(:jsonb)
      table.jsonb name
    else
      table.json name
    end
  end
end
