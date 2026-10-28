import { defineDashboardPlugin } from '@spree/dashboard-core'
import { NewQuestionPage, QuestionDetailPage, QuestionsPage } from './questions'
import { ReviewDetailPage, ReviewsPage } from './reviews'

defineDashboardPlugin({
  nav: {
    addChildren: {
      products: [
        {
          key: 'products.spree-reviews',
          label: 'Reviews',
          path: '/reviews',
          position: 610,
          subject: 'review',
        },
        {
          key: 'products.spree-review-questions',
          label: 'Review questions',
          path: '/review-questions',
          position: 620,
          subject: 'review_question',
        },
      ],
    },
  },
  routes: [
    { key: 'spree-reviews', path: '/reviews', component: ReviewsPage, subject: 'review' },
    {
      key: 'spree-review-detail',
      path: '/reviews/$reviewId',
      component: ReviewDetailPage,
      subject: 'review',
    },
    {
      key: 'spree-review-questions',
      path: '/review-questions',
      component: QuestionsPage,
      subject: 'review_question',
    },
    {
      key: 'spree-review-question-new',
      path: '/review-questions/new',
      component: NewQuestionPage,
      subject: 'review_question',
    },
    {
      key: 'spree-review-question-detail',
      path: '/review-questions/$questionId',
      component: QuestionDetailPage,
      subject: 'review_question',
    },
  ],
})
