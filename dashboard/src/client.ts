import { adminClient } from '@spree/dashboard-core'
import type { Choice, Page, Question, Review } from './types'

export const reviewsClient = {
  list: (page: number, status: string) =>
    adminClient.request<Page<Review>>('GET', '/reviews', {
      params: { page, limit: 25, ...(status ? { 'q[status_eq]': status } : {}) },
    }),
  get: (id: string) => adminClient.request<Review>('GET', `/reviews/${id}`),
  update: (id: string, body: object) =>
    adminClient.request<Review>('PATCH', `/reviews/${id}`, { body }),
  moderate: (id: string, action: 'approve' | 'reject') =>
    adminClient.request<Review>('POST', `/reviews/${id}/${action}`),
  delete: (id: string) => adminClient.request<void>('DELETE', `/reviews/${id}`),
  questions: (page: number) =>
    adminClient.request<Page<Question>>('GET', '/review_questions', {
      params: { page, limit: 25 },
    }),
  question: (id: string) => adminClient.request<Question>('GET', `/review_questions/${id}`),
  createQuestion: (body: object) =>
    adminClient.request<Question>('POST', '/review_questions', { body }),
  updateQuestion: (id: string, body: object) =>
    adminClient.request<Question>('PATCH', `/review_questions/${id}`, { body }),
  deleteQuestion: (id: string) => adminClient.request<void>('DELETE', `/review_questions/${id}`),
  choices: (resource: 'products' | 'categories', page: number, search: string) =>
    adminClient.request<Page<Choice>>('GET', `/${resource}`, {
      params: { page, limit: 50, 'q[search]': search || undefined },
    }),
  product: (id: string) => adminClient.request<Choice>('GET', `/products/${id}`),
}
