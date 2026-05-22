require 'spree'
require 'spree_reviews/engine'
require 'spree_reviews/version'
require 'spree_reviews/configuration'

module SpreeReviews
  mattr_accessor :queue

  def self.queue
    @@queue ||= Spree.queues.default
  end
end
