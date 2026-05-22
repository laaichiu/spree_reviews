Spree::Core::Engine.add_routes do
  namespace :api, defaults: { format: 'json' } do
    namespace :v3 do
      namespace :store do
        resources :products, only: [] do
          resources :reviews, only: [:index, :create] do
            collection do
              get :summary, to: 'review_summaries#show'
              get :filters, to: 'review_filters#index'
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
