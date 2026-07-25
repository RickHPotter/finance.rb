# KAKASHI-14 Category Colours: Implementation Slices

## Delivery Rules

- Complete slices in order.
- Keep each slice independently reviewable and conventionally committed.
- Run `bin/rubocop -A` after every edit batch.
- Load `.env.test` (or `.env` when absent) before RSpec and run database specs with the
  required PostgreSQL permissions.
- Run focused specs throughout and `bin/ci` before the issue is declared complete.
- Do not mix KAKASHI-15 navigation rewrites into these slices.

## Slice 1: Contrast Primitive

Build the pure Ruby normalization/contrast service and exhaustive unit coverage.

Deliver:

- canonical hex normalization
- relative luminance and contrast calculation
- automatic black/white selection
- boundary-safe manual validation
- useful domain errors/results without model or view dependencies

Coverage:

- short and long hex with/without `#`
- uppercase normalization
- pure white/black
- light, dark, mid-luminance, and saturated backgrounds
- malformed, named, alpha, and transparent input
- exactly-at-threshold and just-below-threshold comparisons

Suggested commit:

```text
feat: add category colour contrast contract
```

## Slice 2: Category Persistence and Backfill

Add the explicit colour-mode schema and make category persistence canonical.

Deliver:

- migration/backfill for legacy palette names and existing hex values
- `automatic`/`manual` string-backed mode
- nullable manual text colour
- model normalization and contrast validations
- resolved foreground and contrast accessors
- controller strong parameters and factories

Coverage:

- migration fixtures for named/short/long values
- preservation of every existing background
- automatic default and cleared manual value
- manual required/pass/fail behavior
- built-in and ordinary category updates
- invalid direct request input

Suggested commit:

```text
feat: persist accessible category colour preferences
```

## Slice 3: Shared Presentation API

Replace scattered foreground guesses with one server-side presentation contract and a
reusable Phlex component.

Deliver:

- category colour presentation object/helper
- category chip/swatch component
- safe styles for normal, hover, focus, selected, and disabled states
- explicit multi-category bundle presentation
- delegation/removal plan for legacy `ColoursHelper` methods

Coverage:

- rendered background/foreground pair
- no unsafe text-over-gradient fallback
- focus and disabled attributes/classes
- empty and nil category fallback
- exact string DOM IDs where JavaScript/tests depend on them

Suggested commit:

```text
feat: centralize category colour presentation
```

## Slice 4: Category Form and Live Preview

Add automatic/manual controls and a mathematically matching client preview.

Deliver:

- upgraded colour picker contract
- automatic/manual selector
- manual foreground input
- measured ratio and accessible suggestion
- light/dark surrounding previews
- representative interaction states
- localized validation and explanatory copy

Coverage:

- Stimulus normalization and contrast unit coverage where supported
- request rendering for new/edit
- successful automatic/manual submissions
- failed manual contrast with retained values and concrete message
- no invalid inline styles for partial input
- keyboard labels and live-status semantics

Suggested commit:

```text
feat: preview accessible category colours
```

## Slice 5: Transaction and Allocation Surfaces

Migrate the highest-frequency category surfaces.

Deliver:

- cash/card installment indexes
- cash/card transaction forms and detail screens
- category transaction fields
- budget form allocation fields
- transaction sheets
- multi-allocation bundles

Coverage:

- very light and very dark category rows
- multi-category transaction rendering
- mobile and desktop markup
- selected/disabled allocation states
- no direct `auto_text_color` usage in migrated surfaces

Suggested commit:

```text
feat: apply readable colours to transaction categories
```

## Slice 6: Indexes and Dashboards

Migrate category, budget, subscription, investment, entity, card, and bank-account
surfaces.

Deliver:

- category index/show
- budget index/show
- subscriptions
- investment month/year
- entity dashboards
- user-card and bank-account dashboards
- internal ledger surfaces that share these presenters

Coverage:

- request/view examples for each resource family
- active/inactive and light/dark states
- dashboard labels and summary rows
- no hardcoded foreground over category backgrounds

Suggested commit:

```text
feat: apply readable colours across finance dashboards
```

## Slice 7: Charts and Serialized Data

Make category chart data foreground-aware.

Deliver:

- monthly-analysis payload background/foreground pairs
- pie chart legend and tooltip foreground usage
- deterministic neutral multi-category bundle pair
- accessible text equivalents

Coverage:

- single-category payload
- multi-category payload
- chart legend DOM styling
- fallback palette entries
- payload compatibility during migration

Suggested commit:

```text
feat: expose accessible category chart colours
```

## Slice 8: Enforcement and Regression Sweep

Close gaps and prevent new scattered colour logic.

Deliver:

- repository-wide raw-category-colour audit
- removal of obsolete contrast implementations
- focused guard/spec proving core category surfaces use the presentation contract
- completed English and Portuguese copy
- manual light/dark/mobile verification

Verification:

```sh
bin/rspec spec/models/category_spec.rb
bin/rspec spec/services
bin/rspec spec/requests/categories_spec.rb
bin/rspec spec/requests/cash_transactions_spec.rb
bin/rspec spec/requests/card_transactions_spec.rb
bin/rspec spec/requests/budgets_spec.rb
yarn build
bin/ci
```

Suggested commit:

```text
spec: harden accessible category colour coverage
```
