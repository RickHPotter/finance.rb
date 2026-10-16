# SUMMARY

<!--toc:start-->
- [SUMMARY](#summary)
  - [INTRODUCTION](#introduction)
  - [SPRINT V: NARUTO](#sprint-v-naruto)
    - [NARUTO-01: Create category hierarchy](#naruto-01-create-category-hierarchy)
    - [NARUTO-02: Add bulk and composite transactions](#naruto-02-add-bulk-and-composite-transactions)
    - [NARUTO-03: Attach documents and import Brazilian fiscal receipts](#naruto-03-attach-documents-and-import-brazilian-fiscal-receipts)
    - [NARUTO-04: Extend subscriptions with salary support and bulk operations](#naruto-04-extend-subscriptions-with-salary-support-and-bulk-operations)
    - [NARUTO-05: Add pre-paid and debit card support](#naruto-05-add-pre-paid-and-debit-card-support)
    - [NARUTO-06: Consolidate card and account balance dashboard](#naruto-06-consolidate-card-and-account-balance-dashboard)
    - [NARUTO-07: Harden fiscal import for NF-e and monetary accuracy](#naruto-07-harden-fiscal-import-for-nf-e-and-monetary-accuracy)
    - [NARUTO-08: Read screenshots and photographed documents with OCR](#naruto-08-read-screenshots-and-photographed-documents-with-ocr)
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
orçamentos, with fiscal-receipt import into line items; and the financial
instrument set expands to include recurring income
(salary as subscription), pre-paid and debit cards, and a consolidated view of the
user's full liquid position. Follow-up features harden NF-e imports and monetary
accuracy, then add OCR-assisted entry from screenshots and photographed documents.

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
- built-in system categories were flat in NARUTO-01; NARUTO-04 later makes only its
  four subscription-family built-ins eligible as directly selectable parents of
  custom children, while unrelated built-ins remain flat
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

Status: the original split-purchase scope has since been extended to cover per-line-item
friend repayments and exchange notifications. The transaction breakdown and that
friend-aware extension belong to NARUTO-02; NARUTO-03 only adds receipt/document
handling and the fiscal-document import workflow that can prefill these line
items. The implementation history and current verification limits are recorded in the
[NARUTO-02 implementation status](docs/sprints/5-naruto/naruto-02/02-implementation-slices.md).

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
- one or more active line items activate composite mode; zero line items keep the
  transaction simple. The form presents a "Split Purchase" tab. This replaces the
  earlier two-item minimum so a one-product fiscal receipt can retain its item row.
- split purchase is available for exchange requests and `BORROW RETURN` transactions,
  which may allocate across multiple entities; it is unavailable for `EXCHANGE RETURN`
  projections and other system-managed transaction types
- when a transaction is composite, the parent's own category/entity join records are
  deprecated; reporting and rollback route through line items
- a line item's category is optional; when set, it must be a leaf category
- card installments carry only price and date; the breakdown lives on the parent
  transaction and does not propagate to installments
- a rollback adapter `Audit::Rollback::Adapters::LineItem` is required; attaching
  composite mode is a financial mutation and must be recoverable
- the subscription `subscription_id` FK remains on the parent transaction;
  a composite transaction may be linked to a subscription
- each line item can hold its own repayment allocation and, for cash friend exchanges,
  its own loan/reimbursement intent and exchange schedule; details are edited in the
  shared entity repayment modal and notifications are grouped by friend and intent
- changing a line-item price refreshes its repayment amount and unpaid exchange
  schedule using the saved return percentage; changes that conflict with paid exchanges
  are rejected rather than silently rewriting paid history

Coverage:

- model specs: price-sum validation, one-item composite mode, optional leaf-category
  validation, cascade of audit versions
- request specs: create composite cash transaction, create composite card transaction,
  reject mismatched price sum
- service specs: rollback adapter for LineItem create, update, destroy

References:

- [product and data contract](docs/sprints/5-naruto/naruto-02/01-product-and-data-contract.md)
- [implementation slices](docs/sprints/5-naruto/naruto-02/02-implementation-slices.md)
- [decisions and test matrix](docs/sprints/5-naruto/naruto-02/03-decisions-and-test-matrix.md)

Explicitly out of scope:

- multi-context line items
- CSV import of composite transactions
- three or more nesting levels for line items
- parsing fiscal receipts (NARUTO-03 owns that workflow; its prefill target is this line-item form)

### NARUTO-03: Attach documents and import Brazilian fiscal receipts

Status: attachment support and the first fiscal-import workflow are implemented.
Cash/card index pages open an import modal where authorized XML, Goiás signed QR,
Paraná NFC-e key/QR, PDF text, or a readable image QR can prefill an unsaved
transaction with line items. Imported uploads can be retained as transaction receipts;
category/entity defaults can be applied to all rows and exceptions edited individually.
Goiás key-only lookup remains unavailable because its public page requires a browser
challenge. The supported cash/card import flows have been manually exercised. Duplicate
fiscal-document protection remains a NARUTO-03 bug, and attachment security/deployment
gates remain open. NF-e support and monetary reconciliation move to NARUTO-07; OCR of
screenshots and documents moves to NARUTO-08. Broader state coverage is optional; see
the [NARUTO-03 status and plans](docs/sprints/5-naruto/naruto-03/01-product-and-data-contract.md).

Goal: allow any `CashTransaction`, `CardTransaction`, or `LineItem` to carry one or
more file attachments as documentary evidence, and convert a supported Brazilian cupom
fiscal into reviewable line items in a cash or card transaction draft.

`ActiveStorage` is configured and its tables already exist. V1 adds model declarations,
validators, and cash/card upload and display UI. Attachment security and durable
production storage require the NARUTO-03 hardening V2 plan below.

Locked V1 direction:

- `has_many_attached :receipts` on `CashTransaction`, `CardTransaction`, and `LineItem`
- accepted content types: PDF, JPEG, PNG, HEIC, XML, ZIP
- maximum 10 MiB per file of any accepted type (including every picture), five files
  per record; enforced by model-level validators on all three hosts
- direct upload to ActiveStorage from the browser; no full-page reload
- per-file upload progress rendered by Stimulus in the browser
- attachment delete is audited in the parent transaction's `AuditVersion` metadata
  rather than as a standalone rollback-capable operation; attachments are documentary
  evidence, not financial mutations
- rolling back a transaction does not remove its attachments
- a paperclip icon badge appears on transaction index rows that have attachments
- expanded transaction detail shows a file list with download links and a delete action
- V2 now authorizes receipt downloads and direct uploads and identifies deletions by
  attachment; deployed storage persistence, backup/restore, and remaining security
  failure cases are release gates before the feature is considered complete

Fiscal document import depends on NARUTO-02's transaction line-item form. The
`naruto-03-v2` branch implements the first supported paths: uploaded authorized XML,
Goiás signed QR URL, Paraná NFC-e key/QR, PDF text extraction, and image/camera QR
scanning. These create a reviewable cash/card draft; a short cupom number alone is not
a lookup key. Remaining work and exact state/source limitations are tracked in
`05-v3-brazilian-fiscal-import-plan.md` (the V3 label is the existing document phase,
not the branch name).

Coverage:

- model specs: file type rejection, byte size rejection, max-count enforcement
- request specs: upload, download, delete on cash and card transactions

References:

- [product and data contract](docs/sprints/5-naruto/naruto-03/01-product-and-data-contract.md)
- [implementation slices](docs/sprints/5-naruto/naruto-03/02-implementation-slices.md)
- [decisions and test matrix](docs/sprints/5-naruto/naruto-03/03-decisions-and-test-matrix.md)
- [V2 development plan for pending attachment fixes](docs/sprints/5-naruto/naruto-03/04-v2-development-plan.md)
- [V3 Brazilian fiscal import plan](docs/sprints/5-naruto/naruto-03/05-v3-brazilian-fiscal-import-plan.md)

Explicitly out of scope for the current attachment and fiscal-import plan:

- bank statement PDF parsing
- NF-e model 55 expansion and document-level monetary accuracy (NARUTO-07)
- OCR of screenshots, photos, printed cupoms, NF-e, NFC-e, and orçamentos (NARUTO-08)

### NARUTO-04: Extend subscriptions with salary support and bulk operations

Status: in progress as of 2026-10-16. The salary/OTHER category foundation is implemented
and locally verified; all four main-category families now allow custom children.
Subscription kind/forms, bulk operations, and rollback hardening
remain. The signed-total, cash-only income, immutable-kind, category-choice, and atomic
bulk-edit decisions are locked. See the
[NARUTO-04 product contract](docs/sprints/5-naruto/naruto-04/01-product-and-data-contract.md)
and [implementation slices](docs/sprints/5-naruto/naruto-04/02-implementation-slices.md).

Goal: extend the existing `Subscription` (`finance_subscriptions`) model with three
improvements: salary as a first-class subscription kind, bulk status and allocation
changes, and verified rollback audit coverage.

Currently subscriptions can already contain positive or negative linked transactions,
but have no explicit income/expense kind. Salary, freelance retainers, and rental income
belong in the same recurring workflow and need that distinction. Bulk edit allows pausing
or finishing a set of subscriptions in one audited action. Rollback audit verification
confirms the existing adapter covers every mutation path before new paths are added.

Current direction:

- add `subscription_kind varchar NOT NULL DEFAULT 'expense'` and `main_category_id`
  to `finance_subscriptions`; existing records backfill main `SUBSCRIPTION` while their
  current category join remains the optional **additional** category
- preserve signed cash/card transaction and installment prices; `Subscription#price`
  remains the derived signed sum, not an always-positive amount
- monthly analysis continues to classify actual installment signs; kind describes
  recurring intent and must not invert or double-count cash flow
- add localized salary built-ins, preserving existing `SALARY`/`SALARIO` category IDs
  and allocations and creating a locale-appropriate category only where missing
- add built-in parent categories `OTHER` and `OTHER INCOME`; `SUBSCRIPTION`, salary,
  and both OTHER parents are directly selectable and permit user-created children,
  without adding general category income/expense flags
- the create/edit form offers SUBSCRIPTION (Expense), SALARY (Income), OTHER (Expense),
  and OTHER (Income) as **main-category families**, each showing its custom children;
  the existing category input remains one optional **additional** category of any kind
- new income cash entries default positive; income subscriptions are cash-only and
  kind cannot change after creation, while same-kind category changes can update
  linked transaction allocations
- the selected main category replaces automatic `SUBSCRIPTION` tagging on linked
  transactions; selecting a child attaches that child only, plus any additional
  category (e.g. Netflix: main SUBSCRIPTION, additional LEISURE)
- bulk edit: selection on desktop rows and PWA cards, with localized actions when one
  or more subscriptions are selected
- supported bulk fields: `status`, **additional category**, `entity`; bulk does not
  change main category or kind
- bulk additional-category/entity actions replace allocations with an explicit clear action;
  invalid mixed-state status transitions reject the entire selection
- all selected records update atomically through existing validation/sync paths, with
  one request-scoped audit operation and one operation-level rollback action; no
  `operation_kind` database column exists
- extend the existing `spec/services/audit/rollback/subscription_adapter_spec.rb`
  to cover create, update, destroy, bulk edit, and the new `subscription_kind` field

Coverage:

- model specs: enum validation, price-direction semantics, bulk update isolation
- request specs: create income subscription, bulk status change, bulk category change
- service specs: rollback adapter for all mutation paths including `subscription_kind`
  and bulk edit

References:

- [product and data contract](docs/sprints/5-naruto/naruto-04/01-product-and-data-contract.md)
- [implementation slices](docs/sprints/5-naruto/naruto-04/02-implementation-slices.md)

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

### NARUTO-07: Harden fiscal import for NF-e and monetary accuracy

Status: planned. This extends NARUTO-03's supported NFC-e/cupom import; it does not
reopen the completed manual-validation gate or absorb the NARUTO-03 duplicate-import bug.

Goal: harden the existing basic authorized-XML parser for NF-e (model 55) documents
and investigate the fiscal fields and document-level adjustments needed to represent
NF-e and NFC-e transactions accurately. The current parser can accept a model-55
`nfeProc` structurally, but only model-65 fixtures are covered and NF-e-specific
accuracy is not verified. Start with supplied authorized XML; evaluate DANFE PDF and
state-specific public consultation separately. A 44-digit
key alone is not a promise of automatic XML or product-row retrieval: the official
NF-e consultation has a browser challenge, and distribution of XML has separate
authorization requirements.

The analysis must inventory quantities, units, unit prices, product totals, discounts,
freight, insurance, other charges, taxes, payments, and issuance/cancellation status;
identify which fields belong on the transaction, each `LineItem`, or provenance-only
metadata; and explain how item totals reconcile with the payable amount. Do not
silently alter product prices or invent a balancing item. Present any discrepancy for
review and obtain a product decision on an explicit adjustment representation before
implementation. Preserve the original document and source/provenance metadata.

Coverage: sanitized model-55 XML fixtures, malformed/unauthorized documents, item and
document totals with discounts/charges, status and date handling, cash/card prefill,
attachments, and rejection or review of unresolved differences.

Reference: [NF-e and fiscal-accuracy development plan](docs/sprints/5-naruto/naruto-07/01-product-and-data-contract.md).

### NARUTO-08: Read screenshots and photographed documents with OCR

Status: planned; last feature in this sprint.

Goal: speed up transaction creation from screenshots and photos, not only fiscal
receipts. Support reviewable extraction from ordinary purchase screenshots,
orçamentos, NF-e, NFC-e, and printed cupoms where no usable XML or online lookup is
available. OCR is an assistive draft source, never an authoritative transaction save.

Investigate a privacy-preserving, bounded OCR pipeline with confidence signals and
clear review of uncertain descriptions, dates, totals, and line items. Reuse structured
XML/QR/lookup data when available and compare it with OCR rather than silently choosing
one source. In particular, faded cupom ink may defeat OCR while a QR code works—or
damage the QR while printed text remains legible. Try both routes where possible and
show the user which data was recovered and which still needs manual correction.

Coverage: screenshots, clear/faded cupoms, unreadable QR, conflicting OCR/structured
values, multi-item documents, privacy/security limits, and user correction before save.

Reference: [OCR-assisted transaction entry development plan](docs/sprints/5-naruto/naruto-08/01-product-and-data-contract.md).

## IMPLEMENTATION ROADMAP & BATCHES

The eight tickets are grouped into five development batches based on their dependencies
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
├── NARUTO-03: Transaction Attachments and NFC-e Import
│   ├── has_many_attached :receipts on CashTransaction, CardTransaction, LineItem
│   ├── File validators: content type + byte size
│   ├── Upload UI: Stimulus attachment-upload-controller, direct upload, browser progress
│   ├── Display: attachment list, paperclip badge on index rows, delete action
│   ├── Fiscal import: supported XML/QR sources, saved inbox, cash/card prefill
│   └── Finish duplicate-import protection and attachment release gates
└── NARUTO-04: Subscription Enhancements
    ├── Migration: add subscription_kind and main_category_id to finance_subscriptions
    ├── Built-in: localize/reconcile SALARY/SALARIO; four family parents allow children
    ├── Form: four main families + optional additional category, positive cash-only income
    ├── Bulk edit: desktop/PWA selection, atomic server mutation, existing audit operation
    ├── Rollback audit verification: extend the existing adapter spec
    └── Specs: model + request + rollback adapter

Batch 4: Integration & Reporting (after Batch 2 merges)
├── Update monthly analysis to route category/entity totals through line items
│   when transaction is composite (affects NARUTO-02 + existing reports)
├── Verify income subscription installments appear on the income side without
│   overriding monthly analysis' signed-amount classification (NARUTO-04)
└── Update balance dashboard to reflect debit card transactions correctly (NARUTO-06)

Batch 5: Fiscal Accuracy and Assisted Entry (after NARUTO-03)
├── NARUTO-07: NF-e model 55 import and fiscal monetary-field analysis
│   ├── Analyze source fields, status, and total reconciliation before schema decisions
│   ├── Extend supplied authorized-XML parsing and reviewable cash/card prefill
│   └── Test adjustments, provenance, and unresolved differences
└── NARUTO-08: OCR-assisted entry for screenshots, cupoms, NF-e/NFC-e, and budgets
    ├── Define local/privacy-safe extraction and uncertainty review
    ├── Combine OCR with available XML/QR evidence, especially on faded cupoms
    └── Keep the normal transaction form and user confirmation as the save gate
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
reserve. `NARUTO-07` extends fiscal import to NF-e while investigating the fields and
adjustments required for accurate totals. `NARUTO-08` adds OCR-assisted drafts from
screenshots and photographed documents, including a fallback for damaged cupoms.

The sprint's proposed schema changes are additive and migration-safe. All eight tickets compose
on the KAKASHI-08 audit and rollback foundation: `LineItem` gets its own adapter,
`Subscription` rollback coverage is verified and extended, and `UserCard` rollback is
updated for the new kind field. No existing financial safety rules, exchange semantics,
reference merge behavior, or paid-history guards are modified.
