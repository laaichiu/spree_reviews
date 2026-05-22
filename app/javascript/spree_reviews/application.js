import '@hotwired/turbo-rails'
import { Application } from '@hotwired/stimulus'

let application

if (typeof window.Stimulus === "undefined") {
  application = Application.start()
  application.debug = false
  window.Stimulus = application
} else {
  application = window.Stimulus
}

import SpreeReviewsController from 'spree_reviews/controllers/spree_reviews_controller' 

application.register('spree_reviews', SpreeReviewsController)