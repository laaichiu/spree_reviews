Rails.application.config.after_initialize do
  next unless Spree.respond_to?(:admin)

  sidebar_nav = Spree.admin.navigation.sidebar

  unless sidebar_nav.exists?(:reviews)
    sidebar_nav.add :reviews,
                    label: 'Reviews',
                    url: :admin_reviews_path,
                    parent: :products,
                    position: 45,
                    active: -> { controller_name == 'reviews' },
                    if: -> { can?(:manage, Spree::Review) }
  end

  unless sidebar_nav.exists?(:review_questions)
    sidebar_nav.add :review_questions,
                    label: 'Review questions',
                    url: :admin_review_questions_path,
                    parent: :products,
                    position: 46,
                    active: -> { controller_name == 'review_questions' },
                    if: -> { can?(:manage, Spree::ReviewQuestion) }
  end

  unless Spree.admin.tables.registered?(:reviews)
    review_search_param = %i[
      title body reviewer_name user_first_name user_last_name user_email
    ].join('_or_')
    review_search_param = :"#{review_search_param}_cont"

    Spree.admin.tables.register(
      :reviews,
      model_class: Spree::Review,
      search_param: review_search_param,
      search_placeholder: 'Search reviews',
      row_actions: false,
      new_resource: false,
      date_range_param: :created_at,
      link_to_action: :show
    )

    Spree.admin.tables.reviews.add :title,
                                   label: 'Title',
                                   type: :link,
                                   sortable: true,
                                   filterable: true,
                                   default: true,
                                   position: 10

    Spree.admin.tables.reviews.add :product,
                                   label: 'Product',
                                   type: :string,
                                   sortable: false,
                                   filterable: false,
                                   default: true,
                                   position: 20,
                                   method: ->(review) { review.product&.name }

    Spree.admin.tables.reviews.add :rating,
                                   label: 'Rating',
                                   type: :number,
                                   sortable: true,
                                   filterable: true,
                                   default: true,
                                   position: 30

    Spree.admin.tables.reviews.add :status,
                                   label: 'Status',
                                   type: :status,
                                   sortable: true,
                                   filterable: true,
                                   default: true,
                                   position: 40

    Spree.admin.tables.reviews.add :reviewer_name,
                                   label: 'Reviewer',
                                   type: :custom,
                                   sortable: true,
                                   filterable: true,
                                   default: true,
                                   position: 50,
                                   method: ->(review) { review.admin_reviewer_name },
                                   partial: 'spree/admin/reviews/reviewer',
                                   partial_locals: ->(review) { { review: review } }

    Spree.admin.tables.reviews.add :verified_purchase,
                                   label: 'Verified',
                                   type: :boolean,
                                   sortable: true,
                                   filterable: true,
                                   default: true,
                                   position: 60

    Spree.admin.tables.reviews.add :created_at,
                                   label: 'Submitted',
                                   type: :datetime,
                                   sortable: true,
                                   filterable: true,
                                   default: true,
                                   position: 70
  end

  unless Spree.admin.tables.registered?(:review_questions)
    Spree.admin.tables.register(
      :review_questions,
      model_class: Spree::ReviewQuestion,
      search_param: :key_or_label_cont,
      search_placeholder: 'Search questions',
      row_actions: true,
      row_actions_delete: true
    )

    Spree.admin.tables.review_questions.add :label,
                                            label: 'Label',
                                            type: :link,
                                            sortable: true,
                                            filterable: true,
                                            default: true,
                                            position: 10

    Spree.admin.tables.review_questions.add :key,
                                            label: 'Key',
                                            type: :string,
                                            sortable: true,
                                            filterable: true,
                                            default: true,
                                            position: 20

    Spree.admin.tables.review_questions.add :kind,
                                            label: 'Kind',
                                            type: :string,
                                            sortable: true,
                                            filterable: true,
                                            default: true,
                                            position: 30

    Spree.admin.tables.review_questions.add :applies_to,
                                            label: 'Applies to',
                                            type: :string,
                                            sortable: true,
                                            filterable: true,
                                            default: true,
                                            position: 40

    Spree.admin.tables.review_questions.add :filterable,
                                            label: 'Filterable',
                                            type: :boolean,
                                            sortable: true,
                                            filterable: true,
                                            default: true,
                                            position: 50

    Spree.admin.tables.review_questions.add :required,
                                            label: 'Required',
                                            type: :boolean,
                                            sortable: true,
                                            filterable: true,
                                            default: true,
                                            position: 60

    Spree.admin.tables.review_questions.add :active,
                                            label: 'Active',
                                            type: :boolean,
                                            sortable: true,
                                            filterable: true,
                                            default: true,
                                            position: 70

    Spree.admin.tables.review_questions.add :position,
                                            label: 'Position',
                                            type: :number,
                                            sortable: true,
                                            filterable: true,
                                            default: false,
                                            position: 80
  end
end
