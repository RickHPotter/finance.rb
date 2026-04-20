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
