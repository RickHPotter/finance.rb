# JIRAIYA-02 Planning: First-Class Subscription Flow

## Current State

For this sprint, `Subscription` means a recurring financial intent:
Netflix, ChatGPT, rent, salary, gym, and similar repeated entries.

The app already had a `Subscription` model for web-push endpoints. Slice 1 renamed
that infrastructure concern to `PushSubscription`, so the finance meaning is now
available without mixing product and notification concepts.

The finance domain still has no dedicated recurring-intent record. Users can create
transactions repeatedly, but the app has no first-class way to group those repeated
entries under one subscription concept.

## Main Product Goal

Create a first-class finance subscription flow that lets a user define a recurring
intent once and manage the many related transactions that may come from it over time,
without introducing background scheduling or automatic generation yet.

## Product Direction

Important domain distinction:

- `Investment` behaves like an aggregation source. Many investment records can collapse
  into a single `CashTransaction` based on grouping rules such as `ref_month_year`,
  `user_bank_account`, and `investment_type`.
- `Subscription` should not behave like that. A single subscription should group and
  explain many related `CashTransaction` and/or `CardTransaction` records over time.

That means a subscription is closer to a reusable intent container than to an
autonomous engine.

## Proposed Scope For V1

The first version should stay narrow:

- create a dedicated finance `Subscription` record owned by the user
- store recurring intent, not date-driven automation
- use the subscription form as the place where linked transactions are managed
- keep categories and entities on the subscription itself, then propagate them to linked transactions
- keep transaction history flexible: card today, another card later, cash after that
- keep lifecycle state available through `status`

Things to defer:

- automatic transaction generation
- recurrence dates and schedule engine
- monthly/weekly/custom interval rules
- proration, retries, and provider sync
- detailed lifecycle date tracking

## Data Model Direction

Expected finance `Subscription` fields for V1:

- ownership: `user_id`
- intent seed: `description`, `comment`
- aggregate value: `price`
- categorization and entity assignment
- lifecycle: `status`

Fields intentionally out of V1:

- `user_card_id`
- `user_bank_account_id`
- `transaction_type`
- `starts_on`, `ends_on`, `next_occurrence_on`, `last_generated_on`
- `renews_automatically`
- `paused_at`, `finished_at`

Reason:

- a subscription may move between cards and cash over time
- routing belongs to each generated transaction, not to the subscription record
- scheduling is not part of the current product behavior yet

## Relation Direction

- a subscription has many related transactions
- those links support mixed history across different payment methods
- card and cash transactions use a dedicated `subscription_id`
- the subscription form should be the user-facing workspace for managing those linked records

## Subscription Workspace Direction

The subscription screen should not stop at CRUD for the subscription header.
It should also manage the linked `CashTransaction` and `CardTransaction` rows.

That means the subscription form is composed of:

- subscription header fields: `description`, `comment`, chosen category, chosen entity, `status`
- linked transaction rows underneath

Each linked transaction row should be lighter than the regular cash/card transaction forms:

- `description` comes from the subscription
- category comes from the chosen category plus a built-in `SUBSCRIPTION` category
- entity may already come from the subscription
- `price` stays editable per row
- `user_card_id` or `user_bank_account_id` must be chosen, exclusively and required per row

This keeps the transaction-level routing flexible while avoiding repeated input for the shared subscription meaning.

## Implementation Slices

### Slice 1: Rename push subscriptions

- rename model, controller, routes, request specs, and notifier references
- leave behavior unchanged

### Slice 2: Add finance subscription model

- create schema, validations, enums, and associations
- keep it user-owned, category/entity-capable, and intentionally light
- use string enums when an enum is needed
- do not bake routing or scheduling metadata into the first version

### Slice 3: Link transactions to subscriptions

- decide how card and cash transactions should reference a subscription
- support many related transactions per subscription
- keep linkage flexible enough for mixed payment history

### Slice 4: Subscription workspace UI

- index/new/create/edit/update for finance subscriptions
- use Phlex, Turbo, and existing form patterns
- manage linked cash/card transactions inside the subscription form itself
- support create, update, and destroy of linked transaction rows from that same screen

- #form layout
  - reuse the same description and comment treatment used in cash and card transaction forms
  - below that, render one controls row with:
    - category (`HotwireCombobox`)
    - entity (`HotwireCombobox`)
    - required status (`RubyUI::Combobox`)
    - calculated price, disabled and refreshed after transaction changes
  - below the controls row, place the transaction add actions
  - below the add actions, render one shared scrollable transaction display for both cash and card rows
  - each transaction card should show:
    - `ref_month_year`
    - date
    - account/card destination
    - price
    - edit action
    - destroy action
  - this visible card list may become the display layer, while the real nested fields stay hidden and grouped by parent type

- #nested_fields#add modal form layout
  - `transaction_type` as a card/cash radio input
  - recurrence spacing selector: monthly, every 3 months, every 6 months, yearly
  - starting and ending `ref_month_year`, with the ending value never before the starting one
  - starting date editable, ending date derived and disabled
  - account/card selector switched by `transaction_type`
  - price
  - when start and end point to the same cycle, build one transaction
  - when they span multiple cycles, build one transaction per resulting cycle
  - after save, move the created transactions into the visible nested-fields display

### Slice 5: Assisted recurring workflow

- add a user-triggered helper for creating the next recurring transaction from
  the latest linked subscription row
- keep it explicit, using the existing add-transaction modal as a confirmation
  step
- do not introduce background generation or schedule processing

### Slice 6: Card reference-aware month/year

- keep cash behavior unchanged: cash `ref_month_year` continues to match the
  transaction date month and year
- change card behavior in the subscription modal so displayed
  `start_month_year` and `end_month_year` are derived from the selected card
  reference cycle, not from naively slicing the charge date
- reuse the existing domain rule already implemented through
  `UserCard#calculate_reference_date` and `CardTransaction#build_month_year`
- when the user changes card, start date, end date, or recurrence interval,
  recompute the resulting reference month-years before nested rows are created
- for card rows, preserve `date` as the charge date while treating
  `start_month_year` and `end_month_year` as invoice/reference month-year values
- keep save-time model behavior as the source of truth, but align the UI with
  that same rule so the visible cards do not drift from persisted results
- if needed, expose a lightweight user-card reference endpoint for the modal to
  resolve dates into reference month-years without duplicating billing-cycle
  logic in Stimulus

Expected implementation impact:

- modal UX:
  - cash keeps today’s simple month/date coupling
  - card reference month-year becomes card-aware and may differ from the charge
    date month
  - changing card can shift the visible reference month-year immediately
- server:
  - keep `Subscription#sync_transaction_month_year` and
    `CardTransaction#build_month_year` as authoritative
  - optionally add a JSON endpoint or batch endpoint to resolve reference
    month-years for selected card/date combinations
- tests:
  - request/model coverage for persisted card transactions crossing a closing
    date boundary
  - focused frontend or interaction coverage for modal recalculation behavior

## Open Questions

- Should V1 include income subscriptions, or only expenses?
- Should the built-in category be visible in the UI, or only attached behind the scenes?
- Should V1 show one shared transaction list, or separate cash and card sections inside the form?
- Should `price` be fully derived from related transactions, or cached and refreshed?
- Should the subscription modal call the server for card reference month-years,
  or is it acceptable to duplicate `calculate_reference_date` logic in
  Stimulus?

## Recommendation

Build `JIRAIYA-02` in two issue-sized phases:

1. Rename push `Subscription` to `PushSubscription`.
2. Introduce finance `Subscription` as a recurring-intent record, not as a scheduler.

That keeps the naming clean, avoids mixing infrastructure with finance, and gives us
a realistic first release without over-designing recurrence.
