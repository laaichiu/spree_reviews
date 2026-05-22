module Spree
  module Api
    module V3
      module Store
        class ReviewsController < Store::BaseController
          include Spree::Api::V3::Store::ReviewProductLookup

          before_action :require_authentication!, only: :create

          # GET /api/v3/store/products/:product_id/reviews
          def index
            reviews = filtered_reviews
            @pagy, records = pagy(reviews, page: page, limit: limit)

            render json: {
              data: records.map { |review| serializer_class.new(review, params: serializer_params).to_h },
              meta: collection_meta
            }
          end

          # POST /api/v3/store/products/:product_id/reviews
          def create
            eligibility = Spree::ReviewEligibility.new(
              product: @product,
              store: current_store,
              user: current_user,
              variant: review_variant
            )
            return render_review_eligibility_error(eligibility) unless eligibility.can_review?

            review = @product.reviews.build(review_params)
            review.store = current_store
            review.user = current_user
            review.variant = review_variant
            review.verified_purchase = true
            review.locale ||= current_locale
            review.reviewer_name = reviewer_name_from_order(eligibility.eligible_order) if review.reviewer_name.blank?

            assign_answers(review)
            assign_media(review)

            if review.errors.blank? && review.save
              render json: serializer_class.new(review, params: serializer_params).to_h, status: :created
            else
              render_validation_error(review.errors)
            end
          end

          private

          def filtered_reviews
            reviews = @product.reviews.approved.for_store(current_store).
                      includes(:user, review_media: { attachment_attachment: :blob }, answers: [:question, :option])
            reviews = apply_rating_filter(reviews)
            reviews = reviews.with_images if truthy_param?(params[:with_images])
            reviews = reviews.verified_purchase if truthy_param?(params[:verified_purchase])
            reviews = apply_answer_filters(reviews)
            apply_sort(reviews)
          end

          def apply_rating_filter(reviews)
            ratings = array_param(params[:rating].presence || params[:ratings])
            ratings.present? ? reviews.with_rating(ratings) : reviews
          end

          def apply_answer_filters(reviews)
            answer_filters.each do |question_key, values|
              reviews = reviews.with_answer(question_key: question_key, values: values)
            end
            reviews
          end

          def apply_sort(reviews)
            case params[:sort].to_s
            when 'highest_rating'
              reviews.highest_rating_first
            when 'lowest_rating'
              reviews.lowest_rating_first
            when 'most_helpful'
              reviews.order(helpful_count: :desc, created_at: :desc, id: :desc)
            else
              reviews.recent_first
            end
          end

          def review_params
            params.permit(:rating, :title, :body, :reviewer_name, :locale, metadata: {}).to_h
          end

          def review_variant
            return @review_variant if defined?(@review_variant)

            variant_id = params[:variant_id].presence
            @review_variant = variant_id.present? ? find_product_variant!(variant_id) : nil
          end

          def find_product_variant!(variant_id)
            scope = Spree::Variant.where(product_id: @product.id)

            if Spree::PrefixedId.prefixed_id?(variant_id)
              scope.find_by_prefix_id!(variant_id)
            else
              scope.find(variant_id)
            end
          end

          def assign_answers(review)
            submitted_answers.each do |answer_payload|
              question = find_question(answer_payload[:question_id], answer_payload[:key])

              if question.blank?
                review.errors.add(:answers, :invalid)
                next
              end

              build_answers_for_question(review, question, answer_payload)
            end

            validate_required_answers(review)
          end

          def assign_media(review)
            submitted_images.each_with_index do |image_payload, index|
              signed_id = image_payload[:signed_id].presence || image_payload[:blob_signed_id].presence

              if signed_id.blank?
                review.errors.add(:review_media, :blank)
                next
              end

              blob = ActiveStorage::Blob.find_signed!(signed_id)
              media = review.review_media.build(
                alt: image_payload[:alt],
                position: image_payload[:position].presence || index
              )
              media.attachment.attach(blob)
            end
          rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
            review.errors.add(:review_media, :invalid)
          end

          def submitted_answers
            raw_answers = params[:answers]
            return [] if raw_answers.blank?

            if raw_answers.respond_to?(:to_unsafe_h)
              raw_answers.to_unsafe_h.map do |key, value|
                { key: key, value: value }
              end
            else
              Array(raw_answers).filter_map do |item|
                next item.to_unsafe_h.symbolize_keys if item.respond_to?(:to_unsafe_h)
                next item.symbolize_keys if item.respond_to?(:symbolize_keys)
              end
            end
          end

          def submitted_images
            raw_images = params[:images].presence || params[:media]
            Array(raw_images).filter_map do |item|
              next item.to_unsafe_h.symbolize_keys if item.respond_to?(:to_unsafe_h)
              next item.symbolize_keys if item.respond_to?(:symbolize_keys)
            end
          end

          def build_answers_for_question(review, question, answer_payload)
            values = Array(answer_value(answer_payload))

            case question.kind
            when 'single_select', 'multi_select'
              values.each do |value|
                option = find_option(question, answer_payload[:option_id], value)
                if option.blank?
                  review.errors.add(:answers, :invalid)
                  next
                end

                review.answers.build(question: question, option: option)
              end
            when 'scale'
              review.answers.build(question: question, value_number: values.first)
            when 'boolean'
              review.answers.build(question: question, value_boolean: ActiveModel::Type::Boolean.new.cast(values.first))
            when 'text'
              review.answers.build(question: question, value_text: values.first)
            end
          end

          def find_question(question_id, key)
            @available_questions_by_key ||= Spree::ReviewQuestion.for_product(@product, store: current_store).index_by(&:key)
            @available_questions_by_id ||= Spree::ReviewQuestion.for_product(@product, store: current_store).index_by(&:prefixed_id)
            question_id.present? ? @available_questions_by_id[question_id] : @available_questions_by_key[key]
          end

          def find_option(question, option_id, value)
            options = question.options.active
            return options.find { |option| option.prefixed_id == option_id } if option_id.present?

            options.find { |option| option.value == value.to_s }
          end

          def validate_required_answers(review)
            answered_question_ids = review.answers.map(&:review_question_id).compact
            required_questions = Spree::ReviewQuestion.for_product(@product, store: current_store).where(required: true)

            required_questions.each do |question|
              review.errors.add(:answers, :blank) unless answered_question_ids.include?(question.id)
            end
          end

          def answer_filters
            raw_filters = params[:answers].presence || params[:answer_filters]
            return {} if raw_filters.blank?

            raw_filters = raw_filters.to_unsafe_h if raw_filters.respond_to?(:to_unsafe_h)
            return {} unless raw_filters.respond_to?(:each)

            raw_filters.each_with_object({}) do |(key, value), filters|
              values = array_param(value)
              filters[key] = values if values.present?
            end
          end

          def serializer_class
            Spree::Api::V3::ReviewSerializer
          end

          def collection_meta
            {
              page: @pagy.page,
              limit: @pagy.limit,
              count: @pagy.count,
              pages: @pagy.pages,
              from: @pagy.from,
              to: @pagy.to,
              in: @pagy.in,
              previous: @pagy.previous,
              next: @pagy.next
            }
          end

          def page
            params[:page]&.to_i || 1
          end

          def limit
            [params[:limit]&.to_i || 25, 100].min
          end

          def array_param(value)
            Array(value).flat_map { |item| item.to_s.split(',') }.map(&:presence).compact
          end

          def answer_value(answer_payload)
            return answer_payload[:values] if answer_payload.key?(:values)
            return answer_payload[:value] if answer_payload.key?(:value)

            answer_payload[:option_value]
          end

          def truthy_param?(value)
            ActiveModel::Type::Boolean.new.cast(value)
          end

          def render_review_eligibility_error(eligibility)
            case eligibility.reason
            when Spree::ReviewEligibility::REASON_ALREADY_REVIEWED
              render_error(
                code: 'review_already_exists',
                message: 'You have already reviewed this product.',
                status: :unprocessable_content,
                details: review_eligibility_error_details(eligibility)
              )
            else
              render_error(
                code: 'review_not_allowed',
                message: 'Only verified buyers can review this product.',
                status: :forbidden,
                details: review_eligibility_error_details(eligibility)
              )
            end
          end

          def review_eligibility_error_details(eligibility)
            {
              reason: eligibility.reason,
              product_id: @product.prefixed_id,
              variant_id: eligibility.variant&.prefixed_id,
              review_id: eligibility.existing_review&.prefixed_id,
              verified_purchase: eligibility.verified_purchase?,
              already_reviewed: eligibility.already_reviewed?
            }
          end

          def reviewer_name_from_order(order)
            address = order&.ship_address
            return if address.blank?
            return address.name if address.respond_to?(:name) && address.name.present?

            [
              address.try(:firstname) || address.try(:first_name),
              address.try(:lastname) || address.try(:last_name)
            ].compact_blank.join(' ').presence
          end
        end
      end
    end
  end
end
