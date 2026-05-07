# JIRAIYA-07 Planning: Detail Dashboards

## Goal

Create full-page detail dashboards for the core finance models that currently force
the user to inspect a record through edit forms or month-year rows.

The dashboard pages should explain a record, its accounting impact, its linked
objects, and its safety/history state. They are not plain CRUD show pages.

## In Scope

`JIRAIYA-07/fe-03` covers first-class dashboard pages for:

- `CashTransaction`
- `CardTransaction`
- `Budget`

Each dashboard should be reachable from an explicit, localized `Analyse` action in
the month-year row. Dev/docs terminology stays English, but user-facing labels are
localized. The existing description click behavior stays unchanged and keeps opening
the edit flow.

All V1 dashboards are full-page screens.

## Non-Goals

Do not broaden this feature into:

- a modal or sheet dashboard system
- a new index/datatable rewrite
- a new query language
- paid-history bypasses or mutation-rule changes
- a full analytics/reporting module
- dashboards for every model in one pass

Subscription, investment, account, card, category, and entity dashboards can be
planned later if the pattern proves useful.

## Product Principles

1. A dashboard should answer “what is this record doing?” faster than an edit form.
2. The edit form remains the place to change attributes.
3. The dashboard can expose action buttons, but actions must respect existing safety
   rules.
4. Linked financial state should be visible without requiring the user to jump
   through index filters.
5. Context safety is mandatory. Dashboards read from `current_context`, not all
   user records.
6. Existing Phlex, Tailwind, Hotwire, Stimulus, and RubyUI/custom components remain
   the implementation stack.
7. User-facing copy must be localized even when code and docs use English names.

## Locked Direction

- Add `show` routes for `cash_transactions`, `card_transactions`, and `budgets`.
- Add a dedicated localized `Analyse` action in month-year rows.
- Keep description links pointed at `edit`.
- Use full-page dashboards in V1.
- Include useful action buttons in dashboards:
  - edit
  - duplicate where the model already supports it
  - pay / pay multiple entry points where the existing flow supports it cleanly
  - destroy only through existing guarded flows
- Start with `CashTransaction`.
- Move month-year row actions toward a trailing three-dots dropdown.
- The dropdown should contain context-aware actions such as pay/change paid state,
  analyse, duplicate, and destroy.
- Do not offer duplicate for card payment, card advance, exchange return, or other
  generated/special rows where duplication would be misleading.
- Mobile V1 may use a visible button/dropdown. Swipe actions and card-click-to-show
  can be revisited later.
- Full-page dashboard links should use top-level navigation intentionally.
- Preserve or restore a useful return target where cheap, especially from dashboards
  and `new` flows. A broader return-state system can grow from this feature, but it
  should not block the first dashboard.

## Dashboard Content Model

### Shared Sections

Each dashboard should converge toward a common structure:

- Hero summary
  - description/name
  - amount
  - status
  - context/scenario indicator when relevant
  - primary actions
- Accounting state
  - effective date/month
  - paid/pending/partial state
  - balance impact where meaningful
- Allocations
  - categories
  - entities
  - payer/receiver or exchange participation where meaningful
- Installments
  - date
  - number/count
  - price
  - paid state
  - balance where available
- Links and references
  - subscription links
  - card invoice/advance links
  - exchange returns
  - `reference_transactable` chain
- Safety/history
  - paid-history state
  - locked mutation state when explainable
  - source/apply message state when relevant

Not every model needs every section in V1, but the visual vocabulary should stay
consistent.

### CashTransaction Dashboard

V1 should surface:

- core description, comment, price, date, month/year
- cash account
- categories and entities
- all cash installments
- paid/pending/partial state
- current balance impact from rendered installments
- subscription link if present
- investment/card-payment/card-advance special identity when present
- exchange/reference chain when present
- available actions:
  - edit
  - duplicate
  - pay related installment when there is a single eligible pending installment
  - destroy through existing guarded behavior

### CardTransaction Dashboard

V1 should surface:

- card and billing-cycle summary
- card installments and generated cash invoice links
- categories and entities
- exchanges and exchange-return state
- card advance relationship when present
- paid-history and covered-cycle state where understandable
- available actions:
  - edit
  - duplicate
  - pay in advance where existing rules allow it
  - destroy through existing guarded behavior

### Budget Dashboard

V1 should surface:

- budget description, active state, month/year, amount
- categories and entities that define the budget
- current month consumption against matching cash rows
- remaining amount
- related cash transactions for the month
- available actions:
  - edit
  - destroy

Budget V1 does not need sorting or a mini query language.

## Implementation Slices

### Current Status

- Slice 1 is implemented: context-scoped `show` endpoints and dashboard shells exist
  for cash transactions, card transactions, and budgets.
- Slice 2 is implemented: the cash transaction dashboard now renders summary,
  installments, allocations, references, and primary guarded actions, and cash
  month-year rows expose a localized `Analyse` entry point while description links
  still open edit.
- Slice 3 is implemented: the card transaction dashboard now renders summary,
  card installments, generated invoice cash links, allocations, references,
  exchanges, card advance state, and guarded actions, and card month-year rows
  expose a localized `Analyse` entry point while description links still open edit.
- Slice 4 is implemented: the budget dashboard now renders summary, budget
  definition/rules, allocations, matched month consumption rows, remaining/balance
  state, and guarded actions, and budget month-year rows expose a localized
  `Analyse` entry point while description links still open edit.
- Slice 5 is implemented: cash, card, and budget dashboards now return to useful
  filtered indexes, use full-page navigation intentionally, and the remaining
  dashboard/action polish is documented as shipped.
- Slice 6 is implemented through follow-up polish:
  - `cash_transactions#show`, `card_transactions#show`, and `budgets#show` now
    share the same section-card / collapsible-card vocabulary
  - `Summary` and `Allocations` are merged in the shipped dashboards instead of
    living as separate cards
  - desktop detail tables now consistently place status before price where that
    helps comparison and keep number/date columns visually lighter
  - mobile detail cards are now model-specific instead of forcing one generic
    dashboard card layout
  - grouped exchange rendering replaced earlier flat-list exchange rendering on
    transaction dashboards

### Handoff Snapshot - 2026-04-22

Slice 1 shipped the routing/controller foundation:

- `resources :cash_transactions`, `resources :card_transactions`, and
  `resources :budgets` expose `show`.
- `CashTransactionsController#show`, `CardTransactionsController#show`, and
  `BudgetsController#show` use context-scoped lookups through existing
  `set_*` methods.
- Placeholder Phlex dashboard shells exist for card transactions and budgets.
- Request specs cover rendering and cross-context not-found behavior.

Slice 2 shipped the first real dashboard pattern for cash:

- `Views::CashTransactions::Show` now renders hero/status, summary cards,
  installments, allocations, links/references, and guarded actions.
- Cash dashboard actions include edit, duplicate when allowed, pay when exactly one
  pending cash installment exists, destroy through the existing guarded delete flow,
  and return to the cash index.
- `Views::CashInstallments::Index` now renders a localized `Analyse` link for cash
  month-year rows on desktop and mobile.
- Description links intentionally still point to `edit_cash_transaction_path`.
- Cash month-year row actions now use a compact three-dots dropdown for Analyse,
  Pay/change-date when available, Duplicate when allowed, and Destroy when allowed.
  Destroy uses the app confirm modal rather than the browser confirm dialog.
- Locales were added for dashboard section labels, partial status, cash reference
  labels, `CashInstallment#number`, and `CashTransaction#subscription_id`.
- `spec/requests/cash_transactions_spec.rb` covers the dashboard sections/actions
  and the month-year `Analyse` link while preserving description-to-edit behavior.

Verification already run after Slice 2:

- `ruby -e 'require "yaml"; %w[config/locales/locale.yml config/locales/models/cash_transactions.yml config/locales/models/cash_installments.yml].each { |file| YAML.load_file(file) }; puts "YAML OK"'`
- `bin/rubocop -A`
- `bin/rspec spec/requests/cash_transactions_spec.rb`
- `bin/rspec spec/models spec/concerns spec/requests`

All checks passed in the source session:

- RuboCop: 447 files, 0 offenses.
- Cash request spec: 66 examples, 0 failures.
- Default non-feature suite: 653 examples, 0 failures.

Known working tree from the source session after Slice 2:

- `app/views/cash_installments/index.rb`
- `app/views/cash_transactions/show.rb`
- `config/locales/locale.yml`
- `config/locales/models/cash_installments.yml`
- `config/locales/models/cash_transactions.yml`
- `docs/sprints/3-jiraiya/jiraiya-07/01-detail-dashboard-planning.md`
- `spec/requests/cash_transactions_spec.rb`

Slice 3 shipped the card dashboard pattern:

- `Views::CardTransactions::Show` now renders hero/status, summary cards,
  installments, invoice cash links, allocations, links/references, exchanges, and
  guarded actions.
- Card dashboard actions include edit, duplicate when the card row is not a card
  advance, pay in advance when the existing cycle flow is available, destroy through
  the existing guarded delete flow, and return to the card index.
- `Views::CardInstallments::Index` now renders a localized `Analyse` link for card
  month-year rows on desktop and mobile.
- Description links intentionally still point to `edit_card_transaction_path`.
- Card row action buttons were harmonized into compact square icon buttons, with
  Analyse using the show/eye icon after visual review.
- Locales were added for card dashboard invoice/exchange/reference labels,
  `CardInstallment#number`, and card transaction subscription/advance labels.
- `spec/requests/card_transactions_spec.rb` covers the dashboard sections/actions
  and the month-year `Analyse` link while preserving description-to-edit behavior.

Adjacent action polish after Slice 3:

- Subscription index actions now use the same compact icon-button treatment and
  expose Destroy only when `Subscription#can_be_destroyed?` allows it.
- Investment month-year rows now include a duplicate/copy action that chains from
  the same account and investment type without applying the account-link
  `next_day: true` behavior.

Verification already run after Slice 3:

- `ruby -c app/views/card_transactions/show.rb`
- `ruby -c app/views/card_installments/index.rb`
- `ruby -c spec/requests/card_transactions_spec.rb`
- `ruby -e 'require "yaml"; %w[config/locales/locale.yml config/locales/models/card_transactions.yml config/locales/models/card_installments.yml].each { |file| YAML.load_file(file) }; puts "YAML OK"'`
- `bin/rubocop -A app/views/card_transactions/show.rb app/views/card_installments/index.rb spec/requests/card_transactions_spec.rb`
- `bin/rspec spec/requests/card_transactions_spec.rb:1740 spec/requests/card_transactions_spec.rb:1778`
- `bin/rspec spec/requests/card_transactions_spec.rb`

All checks passed in the source session:

- Card request spec: 51 examples, 0 failures.

Known working tree from the source session after Slice 3:

- `app/views/card_installments/index.rb`
- `app/views/card_transactions/show.rb`
- `config/locales/locale.yml`
- `config/locales/models/card_installments.yml`
- `config/locales/models/card_transactions.yml`
- `docs/sprints/3-jiraiya/jiraiya-07/01-detail-dashboard-planning.md`
- `spec/requests/card_transactions_spec.rb`

Slice 4 shipped the budget dashboard pattern:

- `Views::Budgets::Show` now renders hero/status, summary cards, budget
  definition/rules, category/entity allocations, matched month consumption rows,
  and guarded actions.
- Budget dashboard actions include edit, destroy through the existing guarded modal
  delete flow, and return to the budget index.
- `Views::Budgets::Budgets` now renders a localized `Analyse` link for budget
  month-year rows on desktop and mobile.
- Description links intentionally still point to `edit_budget_path`.
- Locales were added for budget dashboard definition/consumption/status/rule labels
  and missing `Budget#starting_value` / `Budget#balance` model labels.
- `spec/requests/budgets_spec.rb` covers the dashboard sections/actions and the
  month-year `Analyse` link while preserving description-to-edit behavior.

Verification already run after Slice 4:

- `ruby -c app/views/budgets/show.rb`
- `ruby -c app/views/budgets/budgets.rb`
- `ruby -c spec/requests/budgets_spec.rb`
- `ruby -e 'require "yaml"; YAML.load_file("config/locales/locale.yml"); YAML.load_file("config/locales/models/budgets.yml"); puts "YAML OK"'`
- `bin/rubocop -A app/views/budgets/show.rb app/views/budgets/budgets.rb spec/requests/budgets_spec.rb`
- `bin/rspec spec/requests/budgets_spec.rb`

Slice 5 shipped the dashboard navigation/polish pass:

- Cash dashboards now return to the cash index with the source year/month active
  and the source bank account filter applied.
- Card dashboards now return to the card index with the source year/month active
  and the source card filter applied.
- Budget dashboards now return to the budget index with the source year/month
  active and the budget category/entity filters applied.
- Cash and card dashboard destroy actions now use the app confirmation modal
  instead of the browser confirm dialog.
- Budget row actions use the same compact three-dots pattern for `Analyse` and
  guarded `Destroy`, while preserving description-to-edit behavior.
- Dashboard/index links that leave row frames continue to use top-level Turbo
  navigation intentionally.
- Request specs cover the filtered return-link parameters for cash, card, and
  budget dashboards.

Verification already run after Slice 5:

- `ruby -c app/views/cash_transactions/show.rb`
- `ruby -c app/views/card_transactions/show.rb`
- `ruby -c app/views/budgets/show.rb`
- `ruby -c spec/requests/cash_transactions_spec.rb`
- `ruby -c spec/requests/card_transactions_spec.rb`
- `ruby -c spec/requests/budgets_spec.rb`
- `bin/rubocop -A app/views/cash_transactions/show.rb app/views/card_transactions/show.rb app/views/budgets/show.rb spec/requests/cash_transactions_spec.rb spec/requests/card_transactions_spec.rb spec/requests/budgets_spec.rb`
- `bin/rspec spec/requests/cash_transactions_spec.rb:152 spec/requests/card_transactions_spec.rb:1776 spec/requests/budgets_spec.rb`

JIRAIYA-07 is complete unless a later visual review finds more dashboard polish.

Post-slice QA hardening that shipped after the planned rollout:

- submit-loading skeletons were implemented per form for investments, budgets,
  cash transactions, and card transactions
- dashboard duplicate actions were visually harmonized across budget, cash, and
  card show screens
- budget dashboard status logic was corrected for negative-value budgets so
  `Exceeded` is only shown when expense budgets truly cross their limit
- cash/card dashboard links were hardened to avoid rendering broken
  cross-context/cross-user reference links
- shared datetime input behavior was adjusted so tabbing out of the time field
  does not unintentionally resubmit card forms during reactive date edits

### Shipped UI Snapshot

The currently shipped dashboards should now be read as:

- `CardTransaction`
  - full-width `Summary` with embedded category/entity allocations
  - full-width `Installments and Invoices`
  - grouped `Exchanges`
  - `Links and References`
  - desktop installment and invoice tables mirror each other structurally
  - mobile installment cards use a shared header and a split lower half

- `CashTransaction`
  - full-width `Summary` with embedded category/entity allocations
  - full-width `Installments`
  - grouped `Exchanges`
  - `Links and References`
  - desktop installments surface:
    - number
    - reference month/year
    - date
    - paid status
    - price
    - balance
  - mobile installment cards surface:
    - number/count
    - paid status
    - date
    - reference month/year
    - price
    - balance

- `Budget`
  - full-width `Summary` with embedded category/entity allocations
  - `Definition`
  - `Consumption`
  - desktop consumption table surfaces:
    - number
    - source
    - description
    - date
    - paid status
    - price
  - mobile consumption cards surface:
    - number/count
    - paid status
    - date
    - centered description
    - source
    - price

This is the current visual reference for later dashboard work unless a later slice
explicitly changes it.

### Handoff Snapshot - 2026-05-07

The original cash/card/budget dashboard rollout is done. What followed was a long
polish phase plus one new dashboard track for account-level analysis. This section
is the practical source of truth for the next session.

#### Detail Dashboards That Are Functionally Done

- `card_transactions#show`
- `cash_transactions#show`
- `budgets#show`

The current expectation is:

- all three use the same section-card / collapsible-card vocabulary
- `Summary` and `Allocations` are merged
- mobile layouts are intentionally model-specific, not one generic card template
- grouped `Exchanges` replaced flat exchange lists on transaction dashboards
- row/table emphasis was tuned so number/date columns are visually lighter and
  status sits before price where comparison benefits from it

#### Important Transaction-form Fixes That Happened During This Work

Several regressions were found while working on dashboard-adjacent form/UI flows.
These are worth carrying as explicit context because they were non-obvious:

- entity transaction sheets are portaled but still need to submit nested fields as
  part of the owning transaction form
- single existing nested rows must still render:
  - one `entity_transaction`
  - one `category_transaction`
  - one `exchange`
- duplicate/edit/create EXCHANGE flows were restored by fixing:
  - nested row rendering guards
  - modal form ownership
  - duplicate reactive updates
- `CardTransactionsController` now explicitly delegates shared-return counterpart
  update messaging after a successful save by calling
  `Logic::SharedReturnStructureUpdateMessageService` through mirrored cash
  transactions

Those fixes were not dashboard-only polish. They closed real save-path and
notification regressions uncovered while polishing the UI.

#### Expanded Dashboard Track

The dashboard work no longer stops at cash/card/budget. It now also includes:

- `user_bank_accounts#show`
- `user_cards#show`
- `categories#show`
- `entities#show`

#### `user_bank_accounts#show`

The bank-account show page is no longer just an MVP shell.

Current structure:

- header/actions
- merged `Summary`
- `Category Interactive Dashboard`
- `Entity Interactive Dashboard`
- collapsed-by-default `Categories`
- collapsed-by-default `Entities`

Important shipped behavior:

- the original "recent cash transactions" table was removed as the wrong model for
  this page
- the interactive dashboards use a shared Stimulus controller and `chart.js`
- graph points use installment dates/month buckets, not raw transaction creation
  dates
- `ONLY <selected category>` and `ONLY <selected entity>` groups are strict:
  mixed-category and mixed-entity transactions do not leak into those buckets
- built-in exchange-style categories are intentionally excluded from the main
  category select, but supported in the group-button combinations where relevant
- categories/entities sections are collapsed by default and use 3 cards per row on
  desktop

#### `user_cards#show`

`UserCard` now has a real dashboard page following the same vocabulary as account
dashboards.

Current structure:

- header/actions
- merged `Summary`
- `References`
- `Category Interactive Dashboard`
- `Entity Interactive Dashboard`
- collapsed-by-default `Categories`
- collapsed-by-default `Entities`

Important shipped behavior:

- the page is scoped to `current_context`
- references are display-only
- the references section uses a year carousel:
  - `Prev`
  - year badge
  - `Next`
- only references for the selected year are shown, which naturally caps the visible
  set at 12 per year
- the same shared interactive dashboard controller is used here as on bank accounts

#### `categories#show` and `entities#show`

Category/entity dashboards now exist as mirrored show pages.

Current structure:

- `Details`
- counterpart pie chart section:
  - `Entities` on `categories#show`
  - `Categories` on `entities#show`
- `User Bank Accounts`
- `User Cards`

Important shipped behavior:

- pie charts use absolute price values for slice sizing so mixed positive/negative
  sets still render sensibly
- the counterpart section supports a shared multi-source filter that combines:
  - `UserBankAccount`
  - `UserCard`
- that source filter does not use a native multi-select anymore; it now uses the
  shared combobox/checkbox pattern

#### Current State Of The Interactive Breakdown Work

What is stable enough to assume now:

- the category-first and entity-first dashboards share one generic Stimulus
  controller
- strict `ONLY ...` grouping semantics are covered by request specs for both bank
  accounts and cards
- date bucketing has been corrected to use the intended installment/reference
  month-year values
- chart legend toggles remain enabled

Still worth treating as product-sensitive:

- how far the combination-button language should expand
- whether later analytics should apportion mixed allocations instead of treating
  combinations as first-class groups
- whether exchange-heavy categories deserve a separate dashboard mode instead of
  being folded into the current breakdown UI

#### Context / Modal / Index Polish That Also Shipped During This Slice

These do not belong to the original dashboard plan, but they were part of the same
working stream and affect the current UI baseline:

- `contexts#index`, `contexts#show`, and `contexts#new` were visually aligned to
  the app’s newer button/form language
- context switch from the modal now forces a full-page reload
- simple CRUD indexes (`user_bank_accounts`, `user_cards`, `categories`,
  `entities`) were moved toward the `subscriptions#index` row/action pattern
- built-in `MOI` entity is now non-destroyable in the UI/controller path as well

#### Practical Next-session Assumption

If the next session starts from "where are we?", the shortest accurate answer is:

- context purge incident is resolved and hardened
- cash/card/budget dashboards are shipped
- bank account, user card, category, and entity dashboards now exist
- the remaining work in this area is more likely to be polish, reuse, and product
  decisions than route/controller foundation work

### Slice 1. Route And Dashboard Foundation

Goal:

Create the routing/controller/view foundation without building every dashboard at
once.

Deliverables:

- enable `show` routes for cash, card, and budget resources
- add context-scoped `show` lookup in each controller
- introduce shared dashboard presentation primitives only where immediately useful
- add request coverage for context-scoped access and not-found behavior
- establish the first return-target convention for full-page dashboard navigation

Exit condition:

The app has safe `show` endpoints that render placeholder/full-page dashboard shells
without leaking records across contexts.

### Slice 2. CashTransaction Dashboard

Goal:

Ship the first real dashboard and establish the visual/content pattern.

Deliverables:

- implement `Views::CashTransactions::Show`
- add localized `Analyse` actions in cash month-year rows for desktop and mobile
- begin the trailing three-dots row-action dropdown for cash rows if it can be done
  without destabilizing selection behavior
- keep description links pointed at `edit`
- render summary, allocations, installments, links/references, and action area
- add request specs for dashboard rendering and index-row Analyse links

Exit condition:

A user can open a cash transaction dashboard from the month-year row and understand
its installments, status, allocations, and primary actions without opening edit.

### Slice 3. CardTransaction Dashboard

Goal:

Apply the dashboard pattern to card transactions while respecting card invoice and
exchange complexity.

Deliverables:

- implement `Views::CardTransactions::Show`
- add localized `Analyse` actions in card month-year rows for desktop and mobile
- show card installments, invoice/payment relationships, exchanges, and action area
- add request specs for rendering and context-safe access

Exit condition:

Card transactions expose their billing-cycle and linked cash/exchange state through
a full-page dashboard.

### Slice 4. Budget Dashboard

Goal:

Make budgets inspectable without overbuilding budget analytics.

Deliverables:

- implement `Views::Budgets::Show`
- add `Analyse` links in budget month-year rows
- show budget definition, matched month cash rows, consumed amount, and remaining
  amount
- add request specs for rendering and context-safe access

Exit condition:

Budgets have a useful read/action dashboard that explains current month consumption.

### Slice 5. Polish And Cross-Linking

Goal:

Make dashboards feel like part of the existing finance navigation.

Deliverables:

- add consistent dashboard headers/actions
- link from dashboards back to filtered indexes where useful
- ensure Turbo frame behavior uses full-page navigation intentionally
- ensure mobile layout is usable
- update docs with shipped outcome and intentional exclusions

Exit condition:

The dashboard pattern is coherent across cash, card, and budget and ready to be
reused by later models.

## Validation

Prefer request specs for this feature.

Required coverage:

- show routes render for records in `current_context`
- show routes reject records outside `current_context`
- month-year rows include `Analyse` links
- description links remain edit links
- dashboards render the primary linked sections for each model

Feature specs are not required unless a later interaction cannot be protected at the
request/view-output level.

## First Development Step

Start with Slice 1, then immediately implement Slice 2 for `CashTransaction`.

Do not build card or budget dashboards until the cash dashboard establishes the first
usable visual/content pattern.
