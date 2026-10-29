export interface Page<T> {
  data: T[]
  meta: { page: number; pages: number; count: number }
}

export interface Review {
  id: string
  product_id: string
  variant_id: string | null
  customer_id: string | null
  order_id: string | null
  reviewer_name: string | null
  rating: number
  title: string
  body: string | null
  status: 'pending' | 'approved' | 'rejected'
  verified_purchase: boolean
  helpful_count: number
  not_helpful_count: number
  created_at: string
  media: { id: string; url: string | null; alt: string | null }[]
  answers: { id: string; question_label: string; label: string | number | boolean | null }[]
}

export interface QuestionOption {
  id?: string
  value: string
  label: string
  active: boolean
  position: number
  _destroy?: boolean
}

export interface Question {
  id: string
  key: string
  label: string
  kind: 'single_select' | 'multi_select' | 'scale' | 'boolean' | 'text'
  applies_to: 'store' | 'product' | 'category'
  product_id: string | null
  category_id: string | null
  required: boolean
  filterable: boolean
  active: boolean
  position: number
  options: QuestionOption[]
}

export interface Choice {
  id: string
  name: string
  pretty_name?: string | null
  products_count?: number
}
