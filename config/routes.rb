Spree::Core::Engine.add_routes do
  namespace :admin, path: Spree.admin_path do
    resources :reviews, only: [:index, :show, :update, :destroy] do
      member do
        put :approve
        put :reject
      end
    end

    resources :review_questions, except: :show
  end

  namespace :api, defaults: { format: 'json' } do
    namespace :v3 do
      namespace :admin do
        resources :reviews, only: [:index, :show, :update, :destroy] do
          member do
            post :approve
            post :reject
          end
        end

        resources :review_questions, except: [:new, :edit] do
          resources :options, except: [:new, :edit], controller: 'review_question_options'
        end
      end

      namespace :store do
        resources :products, only: [] do
          resources :reviews, only: [:index, :create] do
            collection do
              get :summary, to: 'review_summaries#show'
              get :filters, to: 'review_filters#index'
              get :eligibility, to: 'review_eligibilities#show'
            end
          end
        end

        resources :reviews, only: [] do
          resources :helpful_votes, only: [:create], controller: 'review_votes'
        end

        namespace :review_media do
          resources :direct_uploads, only: [:create], controller: '/spree/api/v3/store/review_media_direct_uploads'
        end
      end
    end
  end
end
