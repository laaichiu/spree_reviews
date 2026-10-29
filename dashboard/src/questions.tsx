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
import { useId, useState } from 'react'
import { reviewsClient } from './client'
import type { RouteProps } from './shared'
import { AppLink, ErrorMessage, Field, href, NativeSelect, Pagination } from './shared'
import type { Choice, Question, QuestionOption } from './types'

export function QuestionsPage({ storeId }: RouteProps) {
  const { permissions } = usePermissions()
  const [page, setPage] = useState(1)
  const query = useQuery({
    queryKey: ['spree-review-questions', storeId, page],
    queryFn: () => reviewsClient.questions(page),
  })
  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Review questions"
        subtitle="Choose the questions customers answer for a product or category."
      />
      {permissions.can('create', 'review_question') && (
        <AppLink
          storeId={storeId}
          path="review-questions/new"
          className="inline-flex self-start rounded-md bg-primary px-4 py-2 text-sm font-medium text-primary-foreground"
        >
          New question
        </AppLink>
      )}
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
                  {['Question', 'Key', 'Type', 'Applies to', 'Status'].map((name) => (
                    <th key={name} className="px-4 py-3 font-medium">
                      {name}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {query.data.data.map((question) => (
                  <tr key={question.id} className="border-t">
                    <td className="px-4 py-3">
                      <AppLink
                        className="font-medium hover:underline"
                        storeId={storeId}
                        path={`review-questions/${question.id}`}
                      >
                        {question.label}
                      </AppLink>
                    </td>
                    <td className="px-4 py-3">{question.key}</td>
                    <td className="px-4 py-3">{question.kind.replaceAll('_', ' ')}</td>
                    <td className="px-4 py-3 capitalize">{question.applies_to}</td>
                    <td className="px-4 py-3">{question.active ? 'Active' : 'Inactive'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
            {query.data.data.length === 0 && (
              <p className="p-6 text-sm text-muted-foreground">
                No questions yet. Add a question to collect structured feedback.
              </p>
            )}
          </div>
          <Pagination page={page} pages={query.data.meta.pages} setPage={setPage} />
        </>
      )}
    </div>
  )
}

export function QuestionDetailPage({ params, storeId }: RouteProps) {
  const id = params.questionId
  const query = useQuery({
    queryKey: ['spree-review-question', storeId, id],
    queryFn: () => reviewsClient.question(id),
    enabled: Boolean(id),
  })
  if (query.isPending) return <Skeleton className="h-48 w-full" />
  if (query.error) return <ErrorMessage error={query.error} />
  return <QuestionEditor key={query.data.id} storeId={storeId} initial={query.data} />
}

export function NewQuestionPage({ storeId }: RouteProps) {
  return <QuestionEditor storeId={storeId} />
}

function QuestionEditor({ storeId, initial }: { storeId: string; initial?: Question }) {
  const { permissions } = usePermissions()
  const canEdit = permissions.can(initial ? 'update' : 'create', 'review_question')
  const queryClient = useQueryClient()
  const [label, setLabel] = useState(initial?.label || '')
  const [key, setKey] = useState(initial?.key || '')
  const [kind, setKind] = useState<Question['kind']>(initial?.kind || 'single_select')
  const [scope, setScope] = useState<Question['applies_to']>(initial?.applies_to || 'category')
  const [productId, setProductId] = useState(initial?.product_id || '')
  const [categoryId, setCategoryId] = useState(initial?.category_id || '')
  const [required, setRequired] = useState(initial?.required || false)
  const [filterable, setFilterable] = useState(initial?.filterable || false)
  const [active, setActive] = useState(initial?.active ?? true)
  const [position, setPosition] = useState(initial?.position || 0)
  const [options, setOptions] = useState<QuestionOption[]>(initial?.options || [])
  const choiceSearchId = useId()
  const [choicePage, setChoicePage] = useState(1)
  const [searchInput, setSearchInput] = useState('')
  const [choiceSearch, setChoiceSearch] = useState('')
  const [selectedChoice, setSelectedChoice] = useState<Choice | undefined>()
  const target = scope === 'product' ? 'products' : 'categories'
  const choices = useQuery({
    queryKey: ['spree-review-choices', storeId, target, choicePage, choiceSearch],
    queryFn: () => reviewsClient.choices(target, choicePage, choiceSearch),
    enabled: scope !== 'store',
  })
  const selectedCategory =
    scope === 'category'
      ? choices.data?.data.find((choice) => choice.id === categoryId) || selectedChoice
      : undefined
  const mutation = useMutation({
    mutationFn: async (action: 'save' | 'delete'): Promise<Question | undefined> => {
      if (action === 'delete' && initial) {
        await reviewsClient.deleteQuestion(initial.id)
        return undefined
      }
      const payload = {
        label,
        key,
        kind,
        applies_to: scope,
        product_id: scope === 'product' ? productId : null,
        category_id: scope === 'category' ? categoryId : null,
        required,
        filterable,
        active,
        position,
        options: options.map((option, index) => ({
          ...option,
          position: index,
        })),
      }
      return initial
        ? reviewsClient.updateQuestion(initial.id, payload)
        : reviewsClient.createQuestion(payload)
    },
    onSuccess: (result, action) => {
      void queryClient.invalidateQueries({
        queryKey: ['spree-review-questions', storeId],
      })
      if (action === 'delete') window.location.assign(href(storeId, 'review-questions'))
      else if (!initial && result)
        window.location.assign(href(storeId, `review-questions/${result.id}`))
      else {
        if (result) setOptions(result.options)
        void queryClient.invalidateQueries({
          queryKey: ['spree-review-question', storeId, initial?.id],
        })
      }
    },
  })
  function updateOption(index: number, patch: Partial<QuestionOption>) {
    setOptions((current) =>
      current.map((option, i) => (i === index ? { ...option, ...patch } : option)),
    )
  }

  return (
    <div className="flex flex-col gap-6">
      <AppLink
        className="text-sm text-muted-foreground hover:underline"
        storeId={storeId}
        path={'review-questions'}
      >
        Back to questions
      </AppLink>
      <PageHeader
        title={initial ? initial.label : 'New review question'}
        subtitle="Configure a reusable question for customer reviews."
      />
      <Card>
        <CardHeader>
          <CardTitle>Question</CardTitle>
        </CardHeader>
        <CardContent className="flex flex-col gap-4">
          <Field label="Label">
            <Input
              value={label}
              disabled={!canEdit}
              onChange={(event) => setLabel(event.target.value)}
            />
          </Field>
          <Field label="Key">
            <Input
              value={key}
              disabled={!canEdit || Boolean(initial)}
              placeholder="Generated from the label if left blank"
              onChange={(event) => setKey(event.target.value)}
            />
          </Field>
          <p className="text-sm text-muted-foreground">
            The key identifies this question in filters and reporting. Keep it stable after
            collecting answers.
          </p>
          <Field label="Answer type">
            <NativeSelect
              value={kind}
              disabled={!canEdit}
              onChange={(event) => setKind(event.target.value as Question['kind'])}
            >
              <option value="single_select">Single select</option>
              <option value="multi_select">Multiple select</option>
              <option value="scale">Scale</option>
              <option value="boolean">Yes or no</option>
              <option value="text">Text</option>
            </NativeSelect>
          </Field>
          <Field label="Applies to">
            <NativeSelect
              value={scope}
              disabled={!canEdit}
              onChange={(event) => {
                setScope(event.target.value as Question['applies_to'])
                setChoicePage(1)
                setChoiceSearch('')
                setSearchInput('')
                setSelectedChoice(undefined)
              }}
            >
              <option value="store">All products in this store</option>
              <option value="category">Category and its descendants</option>
              <option value="product">A specific product</option>
            </NativeSelect>
          </Field>
          {scope !== 'store' && (
            <div className="flex flex-col gap-3">
              <div className="flex flex-col gap-2">
                <label htmlFor={choiceSearchId} className="text-sm font-medium">
                  Search {scope === 'category' ? 'categories' : 'products'}
                </label>
                <div className="flex gap-2">
                  <Input
                    id={choiceSearchId}
                    value={searchInput}
                    disabled={!canEdit}
                    onChange={(event) => setSearchInput(event.target.value)}
                  />
                  <Button
                    variant="outline"
                    disabled={!canEdit}
                    onClick={() => {
                      setChoiceSearch(searchInput)
                      setChoicePage(1)
                    }}
                  >
                    Search
                  </Button>
                </div>
              </div>
              <Field label={scope === 'category' ? 'Category' : 'Product'}>
                <NativeSelect
                  value={scope === 'category' ? categoryId : productId}
                  disabled={!canEdit || choices.isPending}
                  onChange={(event) => {
                    const id = event.target.value
                    setSelectedChoice(choices.data?.data.find((choice) => choice.id === id))
                    if (scope === 'category') setCategoryId(id)
                    else setProductId(id)
                  }}
                >
                  <option value="">Select {scope}</option>
                  {(scope === 'category' ? categoryId : productId) &&
                    !choices.data?.data.some(
                      (choice) => choice.id === (scope === 'category' ? categoryId : productId),
                    ) && (
                      <option value={scope === 'category' ? categoryId : productId}>
                        {selectedChoice?.pretty_name ||
                          selectedChoice?.name ||
                          (scope === 'category' ? categoryId : productId)}
                      </option>
                    )}
                  {choices.data?.data.map((choice) => (
                    <option key={choice.id} value={choice.id}>
                      {choice.pretty_name || choice.name}
                    </option>
                  ))}
                </NativeSelect>
              </Field>
              {choices.data && choices.data.meta.pages > 1 && (
                <Pagination
                  page={choicePage}
                  pages={choices.data.meta.pages}
                  setPage={setChoicePage}
                />
              )}
            </div>
          )}
          {choices.error && <ErrorMessage error={choices.error} />}
          {scope === 'category' && (
            <p className="text-sm text-muted-foreground">
              This question also applies to products in descendant categories.
              {selectedCategory?.products_count != null
                ? ` ${selectedCategory.products_count} ${selectedCategory.products_count === 1 ? 'product matches' : 'products match'}.`
                : ''}
            </p>
          )}
          <Field label="Position">
            <Input
              type="number"
              min={0}
              value={position}
              disabled={!canEdit}
              onChange={(event) => setPosition(Number(event.target.value))}
            />
          </Field>
          <div className="flex flex-wrap gap-5 text-sm">
            {[
              [required, setRequired, 'Required'],
              [filterable, setFilterable, 'Filterable'],
              [active, setActive, 'Active'],
            ].map(([checked, setter, text]) => (
              <label key={text as string} className="flex items-center gap-2">
                <input
                  type="checkbox"
                  disabled={!canEdit}
                  checked={checked as boolean}
                  onChange={(event) => (setter as (value: boolean) => void)(event.target.checked)}
                />
                {text as string}
              </label>
            ))}
          </div>
        </CardContent>
      </Card>
      {(kind === 'single_select' || kind === 'multi_select') && (
        <Card>
          <CardHeader>
            <CardTitle>Answer options</CardTitle>
          </CardHeader>
          <CardContent className="flex flex-col gap-3">
            {options.map(
              (option, index) =>
                !option._destroy && (
                  <div
                    key={option.id || `new-${index}`}
                    className="grid gap-3 sm:grid-cols-[1fr_1fr_auto_auto]"
                  >
                    <Field label="Label">
                      <Input
                        value={option.label}
                        disabled={!canEdit}
                        onChange={(event) => updateOption(index, { label: event.target.value })}
                      />
                    </Field>
                    <Field label="Value">
                      <Input
                        value={option.value}
                        disabled={!canEdit}
                        onChange={(event) => updateOption(index, { value: event.target.value })}
                      />
                    </Field>
                    <label className="flex items-center gap-2 self-end pb-2 text-sm">
                      <input
                        type="checkbox"
                        checked={option.active}
                        disabled={!canEdit}
                        onChange={(event) => updateOption(index, { active: event.target.checked })}
                      />
                      Active
                    </label>
                    {canEdit && (
                      <Button
                        className="self-end justify-self-start"
                        variant="outline"
                        onClick={() =>
                          option.id
                            ? updateOption(index, { _destroy: true })
                            : setOptions((current) => current.filter((_, i) => i !== index))
                        }
                      >
                        Remove
                      </Button>
                    )}
                  </div>
                ),
            )}
            {canEdit && (
              <Button
                className="self-start"
                variant="outline"
                onClick={() =>
                  setOptions((current) => [
                    ...current,
                    {
                      value: '',
                      label: '',
                      active: true,
                      position: current.length,
                    },
                  ])
                }
              >
                Add option
              </Button>
            )}
          </CardContent>
        </Card>
      )}
      {mutation.error && <ErrorMessage error={mutation.error} />}
      {mutation.isSuccess && (
        <p role="status" className="text-sm text-muted-foreground">
          Question saved.
        </p>
      )}
      {canEdit && (
        <div className="flex gap-2">
          <Button
            disabled={
              mutation.isPending ||
              !label.trim() ||
              (scope === 'product' && !productId) ||
              (scope === 'category' && !categoryId)
            }
            onClick={() => mutation.mutate('save')}
          >
            Save question
          </Button>
          {initial && (
            <Button
              variant="outline"
              disabled={mutation.isPending}
              onClick={() => {
                if (window.confirm('Delete this question and its answers?'))
                  mutation.mutate('delete')
              }}
            >
              Delete
            </Button>
          )}
        </div>
      )}
    </div>
  )
}
