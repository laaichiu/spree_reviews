module SpreeReviews
  class BaseJob < Spree::BaseJob
    queue_as SpreeReviews.queue
  end
end
