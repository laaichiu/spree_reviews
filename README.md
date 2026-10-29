# Spree Reviews

Spree Reviews is a Spree 6 extension for customer reviews. It includes a Rails engine for the Store and Admin APIs and an unpublished React plugin for the Spree dashboard. Storefronts consume the Store API and provide their own review interface.

## Compatibility

- Ruby `>= 3.2`
- Spree dependency range: `>= 6.0`, `< 7.0`

The gem dependency range is not a verified compatibility matrix for every Spree 6 release. Check the integration suite and dashboard typecheck against the host application's Spree version before a production release.

## Features

- Product reviews with 1–5 star ratings, titles, optional written content, moderation status, reviewer display names, locale, and timestamps.
- Verified-purchase reviews with eligibility checked against shipped order items and retained quantities.
- Review images with content-type, size, and per-review count limits.
- Store-, category-, and product-scoped questions with configurable answer types.
- Rating summaries and filters for rating, question answers, images, and verified purchase.
- Helpful and not-helpful votes.
- Dashboard screens for review moderation and question management.

Review image uploads use Active Storage; configure the host application's storage service for the target environment. Video uploads are not supported.

## Install the Rails engine

Add the gem to the host application's `Gemfile`:

```ruby
gem 'spree_reviews', github: 'laaichiu/spree_reviews'
```

Then install the gem and its database migrations:

```sh
bundle install
bin/rails generate spree_reviews:install
```

The generator installs the extension migrations and runs them by default. To install the migrations without running them, use `--no-migrate`, review the pending changes, then run `bin/rails db:migrate` when ready.

### Existing installations with review data

Skip this section when installing Spree Reviews into a new Spree 6 store. For an existing installation, back up the database and verify review, vote, customer, and purchase associations in staging. If the host is still on Spree 5, upgrade it to Spree 6 first and complete Spree's customer data migration before updating this extension and running its migrations.

Run these repair tasks only when existing review records need purchase attribution or verified-purchase flags refreshed. Preview each task before applying it:

```sh
bundle exec rake spree_reviews:backfill_review_purchase_links DRY_RUN=true
bundle exec rake spree_reviews:refresh_verified_purchase DRY_RUN=true
```

After reviewing the output, run the tasks without `DRY_RUN=true` to apply the updates:

```sh
bundle exec rake spree_reviews:backfill_review_purchase_links
bundle exec rake spree_reviews:refresh_verified_purchase
```

The attribution task links a review to a matching shipped purchase and assigns a variant only when the match is unambiguous. The verified-purchase task recalculates flags using current order and return state.

## Preview the dashboard plugin

The dashboard plugin source is in `dashboard/` and has not been published to a package registry. To preview it during development, use Spree's `dashboard-starter`, which discovers installed plugins automatically. If the `spree` and `spree_reviews` repositories are checked out as sibling directories, run:

```sh
cd spree/packages/dashboard-starter
pnpm add '@spree-reviews/dashboard@file:../../../spree_reviews/dashboard'
pnpm dev --port 5175
```

Adjust the `file:` path if your checkouts use a different layout. The plugin registers Reviews and Review questions screens through Spree's dashboard plugin API and uses this extension's Admin API. A registry installation command will be documented after the package is published.

## API overview

The Store API provides:

- `GET /api/v3/store/products/:product_id/reviews`
- `GET /api/v3/store/products/:product_id/reviews/summary`
- `GET /api/v3/store/products/:product_id/reviews/filters`
- `GET /api/v3/store/products/:product_id/reviews/questions`
- `GET /api/v3/store/products/:product_id/reviews/eligibility`
- `POST /api/v3/store/products/:product_id/reviews`
- `POST /api/v3/store/review_media/direct_uploads`
- `POST /api/v3/store/reviews/:review_id/helpful_votes`

The Admin API provides review listing and detail, editing, approval, rejection, and deletion under `/api/v3/admin/reviews`, plus CRUD endpoints for review questions and their options. Admin API requests use Spree's normal Admin API authentication and permission checks. The extension's `reviews` permission scope provides `read_reviews` for viewing reviews and questions and `write_reviews` for editing, moderating, and managing them.

Store API review submission requires an authenticated customer with an eligible shipped purchase. The server derives verified-purchase status from order and return data; clients cannot set it directly.

## Local development

To develop against a local Spree checkout, set `SPREE_PATH` to the checkout's `spree/` gem directory before installing dependencies:

```sh
export SPREE_PATH=/path/to/spree/spree
bundle install
```

Run the extension specs with `bundle exec rspec`. The dummy app can be generated with `bundle exec rake test_app`; this replaces `spec/dummy` and drops its test database, so use a disposable checkout if that directory or database contains work you need to keep.

The dashboard package provides a typecheck script:

```sh
cd dashboard
pnpm typecheck
```

## License

Spree Reviews is released under the [MIT License](LICENSE.md).
