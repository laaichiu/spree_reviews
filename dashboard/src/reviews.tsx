import { PageHeader, usePermissions } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Input,
  Skeleton,
} from '@spree/dashboard-ui'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import { reviewsClient } from './client'
import type { RouteProps } from './shared'
import { AppLink, ErrorMessage, Field, href, inputClass, NativeSelect, Pagination } from './shared'
import type { Review } from './types'

export function ReviewsPage({ storeId }: RouteProps) {
  const [page, setPage] = useState(1)
  const [status, setStatus] = useState('')
  const query = useQuery({
    queryKey: ['spree-reviews', storeId, page, status],
    queryFn: () => reviewsClient.list(page, status),
  })

  return (
    <div className="flex flex-col gap-6">
      <PageHeader title="Reviews" subtitle="Review customer feedback and moderation status." />
      <div className="max-w-48">
        <Field label="Status">
          <NativeSelect
            value={status}
            onChange={(event) => {
              setStatus(event.target.value)
              setPage(1)
            }}
          >
            <option value="">All reviews</option>
            <option value="pending">Pending</option>
            <option value="approved">Approved</option>
            <option value="rejected">Rejected</option>
          </NativeSelect>
        </Field>
      </div>
      {query.isPending ? (
        <Skeleton className="h-48 w-full" />
      ) : query.error ? (
        <ErrorMessage error={query.error} />
      ) : (
        <>
          <div className="overflow-x-auto rounded-md border">
            <table className="w-full text-left text-sm">
              <thead className="bg-muted/40">
                <tr>
                  {[
                    'Review',
                    'Rating',
                    'Status',
                    'Helpful',
                    'Not helpful',
                    'Verified purchase',
                    'Submitted',
                  ].map((name) => (
                    <th key={name} className="px-4 py-3 font-medium">
                      {name}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {query.data.data.map((review) => (
                  <tr key={review.id} className="border-t">
                    <td className="px-4 py-3">
                      <AppLink
                        className="font-medium underline-offset-4 hover:underline"
                        storeId={storeId}
                        path={`reviews/${review.id}`}
                      >
                        {review.title || 'Untitled review'}
                      </AppLink>
                      <p className="mt-1 max-w-md truncate text-muted-foreground">{review.body}</p>
                    </td>
                    <td className="px-4 py-3">{review.rating} / 5</td>
                    <td className="px-4 py-3 capitalize">{review.status}</td>
                    <td className="px-4 py-3 tabular-nums">{review.helpful_count}</td>
                    <td className="px-4 py-3 tabular-nums">{review.not_helpful_count}</td>
                    <td className="px-4 py-3">{review.verified_purchase ? 'Yes' : 'No'}</td>
                    <td className="px-4 py-3">
                      {new Date(review.created_at).toLocaleDateString()}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            {query.data.data.length === 0 && (
              <p className="p-6 text-sm text-muted-foreground">No reviews match this filter.</p>
            )}
          </div>
          <Pagination page={page} pages={query.data.meta.pages} setPage={setPage} />
        </>
      )}
    </div>
  )
}

export function ReviewDetailPage({ params, storeId }: RouteProps) {
  const id = params.reviewId
  const query = useQuery({
    queryKey: ['spree-review', storeId, id],
    queryFn: () => reviewsClient.get(id),
    enabled: Boolean(id),
  })
  if (query.isPending) return <Skeleton className="h-48 w-full" />
  if (query.error) return <ErrorMessage error={query.error} />
  return <ReviewEditor key={query.data.id} review={query.data} storeId={storeId} />
}

function ReviewEditor({ review, storeId }: { review: Review; storeId: string }) {
  const { permissions } = usePermissions()
  const canEdit = permissions.can('update', 'review')
  const queryClient = useQueryClient()
  const [title, setTitle] = useState(review.title || '')
  const [body, setBody] = useState(review.body || '')
  const [rating, setRating] = useState(review.rating)
  const product = useQuery({
    queryKey: ['spree-review-product', storeId, review.product_id],
    queryFn: () => reviewsClient.product(review.product_id),
    retry: false,
  })
  const mutation = useMutation({
    mutationFn: async (
      action: 'save' | 'approve' | 'reject' | 'delete',
    ): Promise<Review | undefined> => {
      if (action === 'save') return reviewsClient.update(review.id, { title, body, rating })
      if (action === 'delete') {
        await reviewsClient.delete(review.id)
        return undefined
      }
      return reviewsClient.moderate(review.id, action)
    },
    onSuccess: (_data, action) => {
      void queryClient.invalidateQueries({
        queryKey: ['spree-review', storeId, review.id],
      })
      void queryClient.invalidateQueries({
        queryKey: ['spree-reviews', storeId],
      })
      if (action === 'delete') window.location.assign(href(storeId, 'reviews'))
    },
  })

  return (
    <div className="flex flex-col gap-6">
      <AppLink
        className="text-sm text-muted-foreground hover:underline"
        storeId={storeId}
        path={'reviews'}
      >
        Back to reviews
      </AppLink>
      <PageHeader
        title={review.title || 'Review'}
        subtitle={`${review.status} · ${review.verified_purchase ? 'Verified purchase' : 'Purchase not verified'}`}
      />
      <div className="grid gap-6 lg:grid-cols-[minmax(0,2fr)_minmax(16rem,1fr)]">
        <div className="flex flex-col gap-6">
          <Card>
            <CardHeader>
              <CardTitle>Customer votes</CardTitle>
            </CardHeader>
            <CardContent>
              <dl className="grid grid-cols-2 gap-4 text-sm">
                <div>
                  <dt className="text-muted-foreground">Helpful</dt>
                  <dd className="mt-1 text-2xl font-semibold tabular-nums">
                    {review.helpful_count}
                  </dd>
                </div>
                <div>
                  <dt className="text-muted-foreground">Not helpful</dt>
                  <dd className="mt-1 text-2xl font-semibold tabular-nums">
                    {review.not_helpful_count}
                  </dd>
                </div>
              </dl>
            </CardContent>
          </Card>
          <Card>
            <CardHeader>
              <CardTitle>Review</CardTitle>
            </CardHeader>
            <CardContent className="flex flex-col gap-4">
              <Field label="Title">
                <Input
                  maxLength={120}
                  value={title}
                  disabled={!canEdit}
                  onChange={(event) => setTitle(event.target.value)}
                />
              </Field>
              <Field label="Rating">
                <NativeSelect
                  value={rating}
                  disabled={!canEdit}
                  onChange={(event) => setRating(Number(event.target.value))}
                >
                  {[1, 2, 3, 4, 5].map((value) => (
                    <option key={value} value={value}>
                      {value} / 5
                    </option>
                  ))}
                </NativeSelect>
              </Field>
              <Field label="Review content">
                <textarea
                  className={`${inputClass} min-h-32`}
                  value={body}
                  disabled={!canEdit}
                  onChange={(event) => setBody(event.target.value)}
                />
              </Field>
              {canEdit && (
                <div className="flex flex-wrap gap-2">
                  <Button
                    disabled={mutation.isPending || !title.trim()}
                    onClick={() => mutation.mutate('save')}
                  >
                    Save changes
                  </Button>
                  <Button
                    variant="outline"
                    disabled={mutation.isPending || review.status === 'approved'}
                    onClick={() => mutation.mutate('approve')}
                  >
                    Approve
                  </Button>
                  <Button
                    variant="outline"
                    disabled={mutation.isPending || review.status === 'rejected'}
                    onClick={() => mutation.mutate('reject')}
                  >
                    Reject
                  </Button>
                  <Button
                    variant="outline"
                    disabled={mutation.isPending}
                    onClick={() => {
                      if (window.confirm('Delete this review?')) mutation.mutate('delete')
                    }}
                  >
                    Delete
                  </Button>
                </div>
              )}
              {mutation.error && <ErrorMessage error={mutation.error} />}
              {mutation.isSuccess && (
                <p role="status" className="text-sm text-muted-foreground">
                  Review updated.
                </p>
              )}
            </CardContent>
          </Card>
          {review.answers.length > 0 && (
            <Card>
              <CardHeader>
                <CardTitle>Answers</CardTitle>
              </CardHeader>
              <CardContent>
                <dl className="flex flex-col gap-3 text-sm">
                  {review.answers.map((answer) => (
                    <div key={answer.id}>
                      <dt className="font-medium">{answer.question_label}</dt>
                      <dd className="text-muted-foreground">{String(answer.label ?? '—')}</dd>
                    </div>
                  ))}
                </dl>
              </CardContent>
            </Card>
          )}
          {review.media.length > 0 && (
            <Card>
              <CardHeader>
                <CardTitle>Photos</CardTitle>
              </CardHeader>
              <CardContent className="flex flex-wrap gap-3">
                {review.media.map(
                  (image) =>
                    image.url && (
                      <a key={image.id} href={image.url} target="_blank" rel="noreferrer">
                        <img
                          src={image.url}
                          alt={image.alt || 'Review photo'}
                          className="h-24 w-24 rounded-md object-cover"
                        />
                      </a>
                    ),
                )}
              </CardContent>
            </Card>
          )}
        </div>
        <Card className="h-fit">
          <CardHeader>
            <CardTitle>Purchase context</CardTitle>
          </CardHeader>
          <CardContent>
            <dl className="flex flex-col gap-4 text-sm">
              <div>
                <dt className="text-muted-foreground">Product</dt>
                <dd>
                  <AppLink
                    className="hover:underline"
                    storeId={storeId}
                    path={`products/${review.product_id}`}
                  >
                    {product.data?.name || review.product_id}
                  </AppLink>
                </dd>
              </div>
              <div>
                <dt className="text-muted-foreground">Customer</dt>
                <dd>
                  {review.customer_id ? (
                    <AppLink
                      className="hover:underline"
                      storeId={storeId}
                      path={`customers/${review.customer_id}`}
                    >
                      {review.reviewer_name || 'Customer'}
                    </AppLink>
                  ) : (
                    review.reviewer_name || 'Anonymous'
                  )}
                </dd>
              </div>
              <div>
                <dt className="text-muted-foreground">Order</dt>
                <dd>
                  {review.order_id ? (
                    <AppLink
                      className="hover:underline"
                      storeId={storeId}
                      path={`orders/${review.order_id}`}
                    >
                      {review.order_id}
                    </AppLink>
                  ) : (
                    'Not attributed'
                  )}
                </dd>
              </div>
              <div>
                <dt className="text-muted-foreground">Variant</dt>
                <dd>{review.variant_id || 'Not attributed'}</dd>
              </div>
            </dl>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
