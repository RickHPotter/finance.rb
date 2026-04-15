# JIRAIYA-03 Planning: Datatables, Filters, and Ordering

## Goal

Rework the main finance indexes so they feel easier to scan, easier to control, and
more predictable under repeated daily use.

This is primarily an index-state and interaction track, not a dashboard track and
not a backend-rule rewrite.

## Entry Criteria

These preconditions are already satisfied in the shipped repo state:

- JIRAIYA-04 safety/runtime normalization is complete.
- JIRAIYA-05 bulk-selection behavior is already live on the card and cash indexes.
- the app already has month-grouped Turbo index rendering for card, cash, and budget
  surfaces
- there is no missing foundational CRUD work blocking index refinement first

That means `JIRAIYA-03` can start from product and interaction goals instead of
needing another hidden stabilization pass first.

## Current Baseline

### 1. The main finance indexes are not true datatables today

The user-facing indexes for `CardTransaction`, `CashTransaction`, and `Budget` are
server-rendered month-grouped surfaces.

Current shape:

- the index page renders a search/filter shell
- active month-year groups are rendered through one shared month-year container
- each month-year group loads through its own Turbo frame request
- rows inside each month-year group are rendered by model-specific Phlex views

This is important because any sorting or filtering change must respect that
month-grouped architecture instead of assuming one flat client-side table.

### 2. The current `datatable` controller is mostly a selection controller on these screens

On the transaction indexes, `datatable_controller.js` mainly owns:

- row selection
- shift-range selection
- bulk-action preparation
- selected total/count feedback
- drag hooks that are still mostly placeholder behavior

It is not the real query engine for card/cash/budget indexes.

That means `JIRAIYA-03` should not start by forcing server-driven finance indexes
into a generic client-side datatable abstraction they do not currently use.

### 3. Structured filters already exist, but the state model is fragmented

The current indexes already support meaningful structured filtering:

- card:
  - search term
  - user card
  - category
  - entity
  - transaction price range
  - installment price range
  - installments count range
  - installments number range
  - `order_by`
- cash:
  - search term
  - bank account
  - category
  - entity
  - transaction price range
  - installment price range
  - installments count range
  - installments number range
  - date range
  - paid / pending
  - skip budgets
- budget:
  - search term
  - category
  - entity

The problem is not “no filters.”
The problem is that filter state is currently spread across:

- controller index-context builders
- search-form views
- month-year container param builders
- month-year endpoint params
- bulk-action round-tripping through serialized index context

That fragmentation makes new ordering and new filters more expensive than they
should be.

### 4. Ordering exists today, but it is not discoverable enough

Ordering is currently only explicit on the card index, and even there it lives
inside the advanced filter sheet as an `order_by` select.

That creates several product problems:

- the visible table header does not communicate that ordering is interactive
- order state feels like hidden filter state instead of visible table state
- only card exposes this explicitly today
- the current shape does not scale well if more sortable columns are added

### 5. Month grouping is product meaning, not only presentation

The current month-year grouping is not accidental chrome.
It reflects real financial grouping:

- card billing/reference cycles
- cash due and paid history
- budget monthly boundaries

So `JIRAIYA-03` should improve datatable behavior inside that grouped model.
It should not flatten everything into one endless table just because sortable
headers are being added.

### 6. Cash index has one extra complication: budgets share the same month view

The cash month-year screen currently renders:

- `CashInstallment` rows first
- `Budget` rows after them in the same month group

That means “sortable cash datatable” is not a pure one-model surface in practice.
Any ordering redesign must decide whether budgets participate in the same sort model
or remain a separate block inside the month group.

## Scope

`JIRAIYA-03` should cover:

1. making ordering visible and clickable from the transaction index headers
2. consolidating index state so filters and sorting travel through one clear
   server-driven contract
3. simplifying common filters while keeping advanced filters available
4. keeping all major filter state shareable through query params and Turbo frame reloads
5. aligning card, cash, and budget index behavior where consistency materially helps
6. leaving a clear boundary for a later advanced-query parser without committing to
   a query language now

## Non-Goals

For now, `JIRAIYA-03` should not include:

- a client-side datagrid rewrite
- flattening card, cash, or budget indexes into one global ungrouped list
- dashboard or `:show` page work from `JIRAIYA-07`
- a global cross-model search surface
- a V1 free-form query language with operators, boolean expressions, or saved queries
- reworking bulk actions beyond what is required to keep them compatible with the new
  index-state contract
- redesigning the `lalas/*` read-only surfaces in the first pass

## Product Principles

1. Sorting should feel like table behavior, not hidden filter behavior.
2. The most common index actions should remain obvious without opening an advanced panel.
3. Month-year grouping should remain part of the mental model.
4. Server-rendered state should stay authoritative; do not split sorting logic between
   server and client unless there is a strong reason.
5. Common index behavior should converge across card, cash, and budget only where the
   underlying financial meaning still matches.
6. New filter power should not make the simple path harder to understand.
7. Query-language ambition should be earned by real limitations in the structured UI,
   not assumed up front.

## Remaining Product Decisions

### 1. Should V1 introduce a dedicated query language?

Current answer: no dedicated search language in V1.

Reason:

- the app already has a substantial structured-filter model
- the main pain today is discoverability and consistency, not expressiveness ceiling
- a query language would add parsing, help text, edge cases, and localization burden
  before the structured state has even been normalized

Direction:

- keep one plain search field for description-like matching
- keep structured filters for categories, entities, amounts, dates, and status
- if needed later, add one parser boundary behind a dedicated parameter such as
  `query`, but do not expose grammar in the first pass

Locked decision:

- no query-language work is part of this feature
- do not reserve or expose a `query` parameter yet

### 2. Should budgets participate in the same sort order as cash installments inside cash index?

Current answer: no shared mixed-model sorting in V1.

Direction:

- cash-installment ordering should govern the cash rows
- budget rows can remain a dedicated block after cash rows inside the month group
- if mixed ordering is ever needed later, it should be designed explicitly as a
  cross-record timeline model instead of being smuggled in through one generic sort

Locked decision:

- keep budgets visible and easy to notice inside the cash month view
- do not enlarge `JIRAIYA-03` into true mixed-model timeline sorting
- dedicated budget-index sorting is also out of scope for this sprint

## Locked Direction For Index Architecture

The intended direction is incremental, not a full replacement of the current index
rendering model.

Preferred direction:

1. keep month-year Turbo rendering
   - keep the shared month-year container pattern
   - keep one request per active month-year group
   - keep month-year groups as the outer navigation unit

2. move toward one canonical index-state contract per surface
   - use one small state object per surface, with a minimal shared base
   - one state object should describe:
     - active months
     - visible filters
     - sort field
     - sort direction
     - surface-specific flags such as `skip_budgets`
   - that same state should drive:
     - main index render
     - month-year frame reloads
     - bulk-action index restoration

3. keep sorting server-authoritative
   - header clicks should update query params and reload through Turbo
   - do not add client-side row sorting for finance indexes in V1
   - deterministic secondary sort keys should remain explicit on the server

4. keep index-state building outside controllers
   - controllers should orchestrate, not build the full state hash
   - state building should live in plain service/PORO objects, not view presenters
   - this is the easiest path to adapt and test while keeping Phlex views simple

5. keep month ordering separate from row ordering
   - active month-year groups continue as the outer chronological structure
   - sorting applies within each month-year group unless a later product decision
     intentionally changes that model

## Locked Direction For Ordering

The current intended scope is:

- remove the idea that ordering belongs only in an advanced filter sheet
- make sortable columns visible in the desktop headers of the in-scope indexes
- keep mobile behavior simpler in the first pass, using an explicit sort control if
  header interaction is not a good fit there
- converge on a shared sort contract such as `sort` + `direction`, instead of adding
  more screen-specific enums over time
- keep backward compatibility during migration by translating legacy card `order_by`
  into the new canonical sort contract internally

Behavior target:

1. visible desktop sorting
   - sortable headers should show current active state
   - clicking the active header should toggle ascending / descending when that makes
     sense for the column
   - non-active sortable headers should still indicate that they can be used

2. stable ordering
   - every sort path should keep a deterministic fallback order
   - repeated reloads of the same state should not visibly shuffle equal-value rows

3. card first-class sortable fields
   - description
   - installment date
   - transaction date
   - installment price
   - not in V1:
     - categories
     - entities
     - actions

4. cash first-class sortable fields
   - description
   - installment date
   - installment price
   - not in V1:
     - categories
     - entities
     - balance
     - actions

5. budget ordering after the pattern is proven
   - dedicated budget index can adopt the same sort contract later
   - budget rows embedded inside cash month groups stay out of mixed-model sorting in V1
   - no dedicated budget sorting is planned in this sprint

6. mobile compatibility
   - if clickable headers are too cramped on mobile, keep a compact sort control there
   - mobile should still use the same underlying sort contract as desktop

7. preserve existing defaults during migration
   - card should keep the current default ordering semantics
   - cash should keep the current default ordering semantics
   - do not introduce a new default sort in Slice 1 just because the parameter shape changes

## Locked Direction For Filters

The intended direction is to separate common filters from advanced filters more
clearly.

Preferred direction:

1. keep one always-visible simple search
   - plain text search remains the main fast path
   - it should stay description-oriented and forgiving

2. promote the most common structured controls
   - the currently visible filters should stay visible
   - category and entity are already close to this status
   - account/card scope and paid-state controls should be judged by actual usage and
     screen density, not by a blanket “show everything” rule

3. keep ranges and low-frequency controls in the advanced sheet
   - amount ranges
   - installments count/number ranges
   - date range
   - flags such as `skip_budgets`

4. expose active-filter feedback
   - the index should make it easier to understand that a filtered state is active
   - prefer a lightweight summary line with a clear/reset action in V1
   - avoid noisy filter-chip proliferation in the first pass

5. normalize boolean/filter semantics
   - cash paid/pending state should round-trip predictably
   - prefer an explicit tri-state control over two separate switches if the component
     stack supports it cleanly
   - empty/default states should not feel like hidden tri-state behavior

6. keep filters query-param based
   - states should remain linkable, bookmarkable, and Turbo-compatible
   - do not move filter truth into ephemeral Stimulus-only state

7. keep account/card scoping explicit
   - `user_card` remains explicit through the current card route/tab model
   - `cash_transactions` may later gain an explicit `user_bank_account_id` filter
   - `card_transactions#search` may later gain explicit `user_card_id` filtering in the
     advanced surface
   - Slice 4 should preserve room for those additions without requiring them immediately

## Implementation Slices

### Slice 1. Current-Surface Audit And State Contract

### Goal

Freeze one canonical state model for the in-scope indexes before changing the UI.

### Deliverables

- document the real filter/sort params currently used by card, cash, and budget
- define the canonical state shape for each index
- map card-specific `order_by` into the new shared sort contract during migration
- identify the minimum shared helper/presenter/service shape needed so state is not
  rebuilt differently in controller, view, month-year container, and bulk restore

Locked direction:

- implement one small state object per surface with a minimal shared base
- commit to canonical `sort` + `direction`
- keep legacy `order_by` translation only as a compatibility bridge
- place state building in plain service/PORO objects

### Exit Condition

The repo has one explicit contract for index state that later slices can build on
instead of extending ad hoc param duplication again.

### Slice 2. Header-Triggered Ordering For Card Index

### Goal

Turn card ordering into visible table behavior.

### Deliverables

- remove card’s dependence on the advanced-sheet-only order selector
- add sortable desktop headers for the first in-scope card columns
- keep the same underlying month-year rendering model
- preserve existing filter state while sorting changes
- update request coverage for month-year responses under the new sort contract

Locked direction:

- sortable card columns in V1:
  - description
  - installment date
  - transaction date
  - installment price
- non-sortable card columns in V1:
  - categories
  - entities
  - actions
- preserve current default card ordering semantics
- mobile uses a compact sort control instead of clickable headers

### Guardrail

Do not broaden this slice into a full card-index redesign.
The first proof point is that header-triggered ordering works cleanly on the current
card surface.

### Slice 3. Cash Ordering And Mixed-Row Guardrails

### Goal

Bring the same visible sort behavior to cash without destabilizing the
cash-plus-budget month view.

### Deliverables

- add cash sortable headers for the first approved cash columns
- keep pay/transfer/subscription bulk flows compatible with the new sort state
- keep budget rows as a separate block after sorted cash rows inside the month group
- add request coverage for sorted month-year cash responses

Locked direction:

- sortable cash columns in V1:
  - description
  - installment date
  - installment price
- non-sortable cash columns in V1:
  - categories
  - entities
  - balance
  - actions
- preserve current default cash ordering semantics
- do not implement mixed budget-plus-cash sorting in this slice

### Guardrail

Do not invent mixed-model sorting in this slice.
If budgets and cash rows need one combined chronological surface later, that should
be planned as a distinct product decision.

### Slice 4. Filter UX Consolidation

### Goal

Make common filter flows easier to use without losing the current expressive filter
set.

### Deliverables

- decide which controls stay always visible and which remain in the advanced sheet
- add a lightweight “filtered state” summary or reset affordance
- normalize paid/pending and empty filter behavior
- reduce repeated per-screen filter-state wiring where possible
- keep mobile behavior functional without copying the desktop layout literally

Locked direction:

- the current visible filter set stays visible
- active-filter feedback should prefer a summary line plus reset/clear path
- paid/pending should move toward an explicit tri-state control if the component
  stack supports it cleanly
- keep account/card scope explicit instead of hiding it behind inferred-only state

Implementation notes:

- keep the current visible desktop/mobile structure and add one shared summary row
  instead of introducing more always-visible controls
- build active-filter summaries from index-state service objects rather than
  controllers so card and cash can share the same rendering contract
- normalize cash paid-state UX around an explicit `all / paid / pending` control
  while still translating to the existing backend search contract internally
- use reset links that clear transient filters without inventing hidden scope
  rules

### Guardrail

This slice is about clarity and consistency, not about adding every imaginable new
filter.

### Slice 5. Budget Follow-Through And Query-Language Boundary

### Goal

Finish the track by aligning the dedicated budget index with the new filter/sort
direction and leaving a clean expansion point for later advanced query work.

### Deliverables

- decide whether dedicated budget index sorting belongs in this sprint or should
  stop at filter/state cleanup
- align budget index state handling with the same general contract used elsewhere
- if useful, add an internal parser boundary for a future `query` parameter without
  exposing a real query grammar yet

Locked direction:

- dedicated budget sorting is out of scope for this sprint
- stop at budget state/filter cleanup
- do not add a future parser boundary or query parameter in this feature

Implementation notes:

- reuse the shared active-filter summary/clear behavior for the dedicated budget index
- keep budget filters limited to the existing search, category, and entity controls
- do not render a budget sort toolbar or expose budget sort controls in this slice
- keep the existing budget month-year grouping and `order_id` row order untouched

### Exit Condition

`JIRAIYA-03` ends with a cleaner shared index-state model, visible ordering on the
main transaction surfaces, and no forced commitment to a premature query language.

## Validation

- request specs should protect real server-driven sort and filter behavior
- month-year endpoint coverage matters more than generic view assertions
- bulk-action index restoration should be checked anywhere index state is serialized
- do not add feature specs unless the interaction cannot be protected another way

## Recommendation

Build `JIRAIYA-03` in this order:

1. normalize index state first
2. prove header sorting on card
3. extend the same contract to cash with explicit budget guardrails
4. only then consolidate filter UX

That keeps the work grounded in the current architecture, delivers visible progress
early, and avoids overcommitting to a query-language or datagrid rewrite before the
real index-state model is coherent.
