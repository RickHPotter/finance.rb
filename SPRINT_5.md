# SUMMARY

<!--toc:start-->
- [SUMMARY](#summary)
  - [INTRODUCTION](#introduction)
  - [SPRINT V: NARUTO](#sprint-v-naruto)
    - [NARUTO-01: Create category hierarchy](#naruto-01-create-category-hierarchy)
    - [NARUTO-02: Add bulk and composite transactions](#naruto-02-add-bulk-and-composite-transactions)
    - [NARUTO-03: Attach documents to transactions](#naruto-03-attach-documents-to-transactions)
    - [NARUTO-04: Extend subscriptions with salary support and bulk operations](#naruto-04-extend-subscriptions-with-salary-support-and-bulk-operations)
    - [NARUTO-05: Add pre-paid and debit card support](#naruto-05-add-pre-paid-and-debit-card-support)
    - [NARUTO-06: Consolidate card and account balance dashboard](#naruto-06-consolidate-card-and-account-balance-dashboard)
  - [IMPLEMENTATION ROADMAP & BATCHES](#implementation-roadmap--batches)
  - [IDEAS](#ideas)
    - [Query language for advanced filtering](#query-language-for-advanced-filtering)
  - [CONCLUSION](#conclusion)
<!--toc:end-->

## INTRODUCTION

Sprint 4 leaves the application with a strong audit and rollback foundation, a
consistent component stack, and several domain expansions: Piggy Bank linked cash
flows, monthly analysis, persistent financial auditing, a health-check workspace,
conversation lifecycle, explicit friendships, readable category colours, correct Turbo
navigation, editable allocations, hardened ledgers, predictable selectors and merges,
and Piggy Bank net-value reconciliation.

The next sprint should use that infrastructure deliberately rather than building around
it. Naruto focuses on making the core financial record more expressive in four
dimensions: categories gain structural depth through parent/child grouping; a single
real-world purchase can be described as one transaction with multiple named line items;
transactions can carry documentary evidence such as receipts, NF-e XML, and
orçamentos; and the financial instrument set expands to include recurring income
(salary as subscription), pre-paid and debit cards, and a consolidated view of the
user's full liquid position.

None of these capabilities require reopening Sprint 4's exchange, rollback, or
reference merge work. They compose cleanly on top of it.

## SPRINT V: NARUTO

### NARUTO-01: Create category hierarchy

Goal: let users organise categories into a two-level parent/child hierarchy so a
family of related spending can be grouped without polluting the flat list.

A parent category is a presentational label (e.g. "HSH" for Home Sweet Home). Its
children are the selectable leaves used on transactions (e.g. "HSH - ASSETS",
"HSH - SUPPLIES", "HSH - LABOUR"). Transactions are always tagged to leaf categories;
the parent is a grouping label only.

Locked V1 direction:

- add `parent_category_id bigint` (nullable, FK, indexed) to `categories`; a
  category without a parent remains a standalone top-level category
- enforce a maximum depth of two through a model validation: a parent cannot itself
  have a parent
- block self-reference with a DB check constraint and a model validation
- child categories are named cleanly without parent prefix (e.g. `LABOUR`, not `HSH - LABOUR`)
- category name uniqueness is scoped to `(user_id, parent_category_id)` using
  `NULLS NOT DISTINCT`, allowing different parents to each have a child with the same name (e.g. `SUPPLIES`)
- direct transactions on parent categories are fully permitted (for niche one-offs and smooth transition)
- child categories render with a compound visual badge: `[ HSH [ LABOUR ] ]`
- both parent and child categories are selectable in transaction forms; typing parent name matches
  both the parent and all its subcategories
- filtering by a parent category encompasses the parent's transactions plus all its subcategories'
  transactions (`category.subtree_ids`); filtering by a child category selects only that child
- deactivating a parent cascades to deactivate all its children
- built-in system categories (EXCHANGE, PIGGY BANK, CARD PAYMENT, SUBSCRIPTION, etc.)
  remain flat; no hierarchy is introduced for them
- the `FinancialAuditable` skip list on `Category` requires no change; the new
  foreign key column carries no financial counter

Coverage:

- model specs: scoped uniqueness, self-reference validation, depth-limit validation,
  parent direct transactions, cascade deactivation, subtree_ids and rollups
- component specs: `CategoryBadge` compound visual for subcategories
- request specs: create child with clean name, scoped uniqueness, parent and child transactions,
  hierarchical search filtering
- factory: `:child_category` trait setting `parent_category_id`

References:

- [product and data contract](docs/sprints/5-naruto/naruto-01/01-product-and-data-contract.md)
- [implementation slices](docs/sprints/5-naruto/naruto-01/02-implementation-slices.md)
- [decisions and test matrix](docs/sprints/5-naruto/naruto-01/03-decisions-and-test-matrix.md)

### NARUTO-02: Add bulk and composite transactions

Goal: let one `CashTransaction` or `CardTransaction` carry multiple named line items,
each with its own description, price, category, and optional entity, so a single
real-world purchase that spans multiple categories (an Amazon order, a supermarket
trip, a home supply run) can be described as one financial record.

The parent transaction is the payment record; the line items are the semantic
breakdown. Simple transactions (no line items) are untouched.

Locked V1 direction:

- new polymorphic `line_items` table with `transactable_type` / `transactable_id`
  referencing `CashTransaction` or `CardTransaction`
- `LineItem` includes `CategoryTransactable`, `EntityTransactable`, and
  `FinancialAuditable`; each line item therefore has its own `category_transactions`
  and `entity_transactions` rows through the same polymorphic join tables already used
  by `CashTransaction` and `CardTransaction`
- parent transaction price must equal the sum of line item prices; validated on save
- at least two line items are required to activate composite mode; the form presents a
  "Split purchase" toggle
- when a transaction is composite, the parent's own category/entity join records are
  deprecated; reporting and rollback route through line items
- line item categories must be leaf categories (NARUTO-01 required)
- card installments carry only price and date; the breakdown lives on the parent
  transaction and does not propagate to installments
- a rollback adapter `Audit::Rollback::Adapters::LineItem` is required; attaching
  composite mode is a financial mutation and must be recoverable
- the subscription `subscription_id` FK remains on the parent transaction;
  a composite transaction may be linked to a subscription

Coverage:

- model specs: price-sum validation, minimum-count validation, leaf-category
  validation, cascade of audit versions
- request specs: create composite cash transaction, create composite card transaction,
  reject mismatched price sum
- service specs: rollback adapter for LineItem create, update, destroy

References:

- [product and data contract](docs/sprints/5-naruto/naruto-02/01-product-and-data-contract.md)

Explicitly out of scope:

- multi-context line items
- CSV import of composite transactions
- three or more nesting levels for line items

### NARUTO-03: Attach documents to transactions

Goal: allow any `CashTransaction`, `CardTransaction`, or `LineItem` to carry one or
more file attachments so transactions have documentary evidence (receipts, NF-e XML,
PDF orçamentos, maintenance invoices, insurance documents, etc.).

`ActiveStorage` is already configured in the application; `active_storage_attachments`
and `active_storage_blobs` already exist in the schema. This feature adds model
declarations, validators, and a upload/display UI on top of the existing infrastructure.

Locked V1 direction:

- `has_many_attached :receipts` on `CashTransaction`, `CardTransaction`, and `LineItem`
- accepted content types: PDF, JPEG, PNG, HEIC, XML, ZIP
- maximum 10 MB per file, 5 files per record; enforced by model-level validators
- direct upload to ActiveStorage from the browser; no full-page reload
- Turbo-streamed upload progress indicator
- attachment delete is audited in the parent transaction's `AuditVersion` metadata
  rather than as a standalone rollback-capable operation; attachments are documentary
  evidence, not financial mutations
- rolling back a transaction does not remove its attachments
- a paperclip icon badge appears on transaction index rows that have attachments
- expanded transaction detail shows a file list with download links and a delete action

Layer 2 — fiscal document extraction (deferred to NARUTO-03 V2):

- parse a Brazilian NF-e XML with `Nokogiri` to extract issuer name, item descriptions,
  and prices and pre-fill a composite transaction form (NARUTO-02)
- follow a cupom fiscal QR-code URL (SEFAZ state endpoint) to extract the same data
- external API calls run through Solid Queue background jobs
- Layer 2 requires NARUTO-02 for the line-item pre-fill step

Coverage:

- model specs: file type rejection, byte size rejection, max-count enforcement
- request specs: upload, download, delete on cash and card transactions

References:

- [product and data contract](docs/sprints/5-naruto/naruto-03/01-product-and-data-contract.md)

Explicitly out of scope:

- OCR of unstructured receipt images
- bank statement PDF parsing
- NF-e XML / cupom fiscal QR-code extraction (Layer 2, deferred)

### NARUTO-04: Extend subscriptions with salary support and bulk operations

Goal: extend the existing `Subscription` (`finance_subscriptions`) model with three
improvements: salary as a first-class subscription kind, bulk status and allocation
changes, and verified rollback audit coverage.

Currently all subscriptions model outgoing expense intents. Salary, freelance
retainers, and rental income are recurring incomes that belong in the same subscription
workflow but lack a signal to distinguish them from expenses. Bulk edit allows pausing
or finishing a set of subscriptions in one audited action. Rollback audit verification
confirms the existing adapter covers every mutation path before new paths are added.

Locked V1 direction:

- add `subscription_kind varchar NOT NULL DEFAULT 'expense'` to `finance_subscriptions`
  with string-backed enum values `expense` and `income`
- `price` is always stored as a positive integer; income vs. expense direction is
  inferred from `subscription_kind` at the reporting layer
- income subscriptions appear on the income side of monthly analysis, not the expense
  side
- the create/edit form gains an income/expense toggle; when `income` is selected,
  the built-in "SALARY" category is suggested as a default if the user has one
- bulk edit: checkbox column on the subscription index, floating action bar when one or
  more subscriptions are selected, `SubscriptionsController#bulk_update` action
- supported bulk fields: `status`, `category`, `entity`
- each bulk edit is wrapped in one `AuditOperation` with `operation_kind:
  "subscription_bulk_edit"`; each affected subscription generates its own
  `AuditVersion` under the shared operation
- individual subscription rollback uses the existing
  `Audit::Rollback::Adapters::Subscription`; bulk edit rolls back record-by-record
  under a single visible rollback action in the audit timeline
- rollback audit verification delivers `spec/services/audit/rollback/adapters/
  subscription_spec.rb` covering create, update, destroy, bulk edit, and the new
  `subscription_kind` field

Coverage:

- model specs: enum validation, price-direction semantics, bulk update isolation
- request specs: create income subscription, bulk status change, bulk category change
- service specs: rollback adapter for all mutation paths including `subscription_kind`
  and bulk edit

References:

- [product and data contract](docs/sprints/5-naruto/naruto-04/01-product-and-data-contract.md)

Explicitly out of scope:

- automatic recurring transaction generation on a schedule
- salary split across multiple bank accounts
- start/end date enforcement or proration

### NARUTO-05: Add pre-paid and debit card support

Goal: introduce a `card_kind` enum on `UserCard` so not every card is assumed to be a
credit card with a billing cycle. This covers VA (Vale Alimentação) and VR (Vale
Refeição) benefit cards, debit cards, gift cards, transport cards, and any pre-loaded
card where spending is direct rather than billed.

Currently recording a transaction on a VA/VR card causes the application to create
`Reference` billing records that are financially meaningless for a pre-paid instrument.
This ticket eliminates that assumption and is the prerequisite for the consolidated
balance dashboard in NARUTO-06.

Locked V1 direction:

- add `card_kind varchar NOT NULL DEFAULT 'credit'` to `user_cards` with string-backed
  enum values `credit`, `prepaid`, and `debit`; all existing user cards default to
  `credit` with no data migration required
- `days_until_due_date`, `due_date_day`, and `credit_limit` become nullable; validated
  as required only `if: :credit?`
- `find_or_create_reference_for` and `calculate_reference_date` are guarded with
  `if: credit?`; all call sites must guard before calling
- `prepaid` and `debit` cards do not generate `Reference` records or invoice cash
  transactions; `CardInstallment` records are still created to track payment timing
- add `user_bank_account_id bigint` (nullable, FK referencing `user_bank_accounts`) to
  `user_cards` for the `debit` variant; this column links the debit card to the bank
  account it draws from and is used by NARUTO-06
- the card form gains a "Card type" selector (Credit / Pre-paid / Debit) that shows or
  hides billing-cycle fields based on selection; debit shows a bank account selector
- `Audit::Rollback::Adapters::UserCard` is updated to handle `card_kind` without
  breaking existing credit card rollbacks

Coverage:

- model specs: kind-conditional validation, reference creation guard, nullable billing
  fields on non-credit cards
- request specs: create pre-paid card, create debit card, create transaction on each,
  confirm no Reference is generated

References:

- [product and data contract](docs/sprints/5-naruto/naruto-05/01-product-and-data-contract.md)

Explicitly out of scope:

- pre-paid card top-up recording convention (deferred to NARUTO-05 V2)
- actual bank account balance deduction (NARUTO-06 scope)
- automatic card reload / top-up modelling

### NARUTO-06: Consolidate card and account balance dashboard

Goal: present a single Balance Dashboard that answers "how much money do I effectively
have, and how much credit is available?" in one screen, grouping all active credit
cards, pre-paid cards, and bank accounts under their respective sections.

Locked V1 direction:

- add `cofrinho_reserve_cents integer` (nullable) to `user_cards`; this is the amount
  the user mentally sets aside from their credit limit as a permanent buffer (e.g.,
  R$ 2 000 never spent); nullable means not set
- model validation: `cofrinho_reserve_cents <= credit_limit` when both are present
- `UserCard#used_credit(context:)`: sum of unpaid `CardInstallment.price` for the card
  and context; computed at request time, not cached
- `UserCard#net_available_credit(context:)`: `credit_limit - used_credit - cofrinho_reserve_cents.to_i`
- `Logic::BalanceDashboard` presenter assembles all three sections for the current
  context and computes portfolio totals
- portfolio totals: total net credit available (sum of all credit cards' net available),
  total bank balance (sum of all active bank account balances), and combined liquid
  position (clearly labelled; available credit is not owned money)
- V1 scopes the dashboard to `current_context` only; an all-context aggregate toggle
  is deferred
- pre-paid cards show spending total only in V1; top-up tracking is deferred until the
  top-up recording convention is defined in NARUTO-05 V2
- `GET /balance` route, `BalanceController#index`, Phlex view `Views::Balance::Index`
- the `cofrinho_reserve_cents` field is editable from the user card edit form with a
  currency-masked input
- "Reserve" in English, "Cofrinho" in pt-BR for the `cofrinho_reserve_cents` label

Requires: NARUTO-05 (for `card_kind` distinction in the pre-paid section).

Coverage:

- model specs: `used_credit`, `net_available_credit`, cofrinho validation
- presenter spec: credit / pre-paid / bank sections with stubbed data, portfolio totals
- request spec: balance dashboard access, context isolation, cofrinho update

References:

- [product and data contract](docs/sprints/5-naruto/naruto-06/01-product-and-data-contract.md)

Explicitly out of scope:

- live bank API / Open Finance integration
- multi-currency consolidation
- investment and piggy bank balances (they have their own pages)
- historical balance trend chart

## IMPLEMENTATION ROADMAP & BATCHES

The six tickets are grouped into four development batches based on their dependencies
and risk profile. Batches 1 and 2 establish the foundational data model changes that
subsequent batches build on. Batch 3 is fully independent and can start any time.

```
Batch 1: Data Model Foundations (start here — unblocks everything else)
├── NARUTO-01: Category Hierarchy
│   ├── Migration: add parent_category_id to categories with scoped uniqueness
│   ├── Model validations: no self-reference, max-depth-1, parent can receive tx
│   ├── HasActive cascade: deactivating parent deactivates children
│   └── Specs: model + request
└── NARUTO-05: Pre-paid / Debit Card Support
    ├── Migration: add card_kind, nullable billing fields, user_bank_account_id FK
    ├── Model: kind-conditional validations, reference creation guard
    ├── Form: card type toggle, conditional billing fields, debit bank account selector
    └── Specs: model + request

Batch 2: Transactional Depth (requires Batch 1)
├── NARUTO-02: Bulk / Composite Transactions  [requires NARUTO-01]
│   ├── Migration: new line_items polymorphic table
│   ├── Model: LineItem with CategoryTransactable, EntityTransactable, FinancialAuditable
│   ├── Rollback adapter: Audit::Rollback::Adapters::LineItem
│   ├── Form: "Split purchase" toggle, dynamic line-item list, running total
│   └── Specs: model + request + rollback
└── NARUTO-06: Consolidated Balance Dashboard  [requires NARUTO-05]
    ├── Migration: add cofrinho_reserve_cents to user_cards
    ├── Service: Logic::BalanceDashboard presenter
    ├── Route + View: /balance with credit/prepaid/bank sections
    └── Specs: presenter + request

Batch 3: Independent Enhancements (can start any time, no blockers)
├── NARUTO-03: Transaction Attachments
│   ├── has_many_attached :receipts on CashTransaction, CardTransaction, LineItem
│   ├── File validators: content type + byte size
│   ├── Upload UI: Stimulus attachment-upload-controller, direct upload, Turbo progress
│   ├── Display: attachment list, paperclip badge on index rows, delete action
│   └── Specs: model + request
└── NARUTO-04: Subscription Enhancements
    ├── Migration: add subscription_kind to finance_subscriptions
    ├── Form: income/expense toggle, income defaults (SALARY category suggestion)
    ├── Bulk edit: checkbox index, bulk_update action, single AuditOperation wrapper
    ├── Rollback audit verification: spec file covering all mutation paths
    └── Specs: model + request + rollback adapter

Batch 4: Integration & Reporting (after Batch 2 merges)
├── Update monthly analysis to route category/entity totals through line items
│   when transaction is composite (affects NARUTO-02 + existing reports)
├── Update income/expense classification for subscription kind (NARUTO-04)
└── Update balance dashboard to reflect debit card transactions correctly (NARUTO-06)
```

## IDEAS

### Query language for advanced filtering

Consider a free-form query language, or first reserve a parser parameter, for advanced
transaction filtering beyond the current explicit controls.

This is intentionally an idea rather than committed Sprint 5 scope. The existing
`sort` + `direction` contract and dedicated filter fields cover the important daily
workflows, while a query grammar would add substantial parsing, validation,
localization, discoverability, and test complexity.

## CONCLUSION

Naruto should leave the application able to model the financial complexity of a real
household: purchases that span multiple categories and users, instruments that are not
credit cards, recurring incomes alongside recurring expenses, and the ability to attach
documentary evidence to any financial record.

`NARUTO-01` establishes the structural precondition for the rest of the sprint by
giving categories a two-level hierarchy that transaction selectors, line items, and
reporting can build on. `NARUTO-02` composes on top of that hierarchy to let a single
payment describe its own semantic breakdown through named line items, each with its
own category and entity. `NARUTO-03` turns every transaction from a data record into a
linked document, using the ActiveStorage infrastructure already present in the schema.
`NARUTO-04` completes the subscription model by adding a first-class income kind,
bulk operations, and verified rollback coverage so salary and subscriptions live in
the same domain without ambiguity. `NARUTO-05` removes the assumption that every card
is a credit card, cleanly separating pre-paid and debit instruments from billing cycle
logic and making the data model accurate before the balance dashboard reads it.
`NARUTO-06` assembles the complete liquid-position picture: credit available, pre-paid
spending, and bank balances in one context-scoped view with a user-defined cofrinho
reserve.

The sprint's schema changes are additive and migration-safe. All six tickets compose
on the KAKASHI-08 audit and rollback foundation: `LineItem` gets its own adapter,
`Subscription` rollback coverage is verified and extended, and `UserCard` rollback is
updated for the new kind field. No existing financial safety rules, exchange semantics,
reference merge behavior, or paid-history guards are modified.
