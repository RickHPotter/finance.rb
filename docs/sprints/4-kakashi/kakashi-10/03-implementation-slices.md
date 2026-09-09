# KAKASHI-10 Implementation Slices

## Delivery Rule

Each slice is independently reviewable, covered, RuboCop-clean, and ends with a
focused commit description. At the end of every slice, implementation stops for
manual review before continuing.

Reporting changes remain read-only. No slice may broaden into financial mutation or
actionable-message behavior without explicit approval.

## Slice 1 — Report State and Canonical Source Rows

**Goal:** establish the shared server-side boundary before changing any dashboard.

### Deliverables

- Add a report query-state value object with canonical date, granularity, paid-state,
  direction, and sort handling.
- Add a canonical typed installment-row query scoped to `current_context`.
- Preserve cash/card date and paid-state semantics.
- Encode KAKASHI-06 special-movement precedence in a reusable classifier or adapter.
- Extend dashboard return navigation to accept only validated report state.
- Add unit/service coverage for boundaries, identity uniqueness, context isolation,
  and invalid input.

### Acceptance

- Allocation joins cannot duplicate a source installment.
- Invalid/reversed/oversized ranges never fall back to unbounded history.
- Cash and card source identities cannot collide.
- Existing KAKASHI-06 monthly payload remains unchanged.
- Existing KAKASHI-17 navigation safety remains green.

### Suggested commit

`feat: establish connected report query contracts`

## Slice 2 — Category and Entity Trend Services

**Goal:** deliver the first workflow report through testable service objects.

### Deliverables

- Add range-based category and entity trend finders over canonical ordinary rows.
- Preserve deterministic multi-allocation bundles and neutral unassigned behavior.
- Return income, outcome, net, ordered buckets, counterpart breakdowns, typed source
  counts, and exact cash/card drill-down URLs.
- Add lazy JSON endpoints scoped through the owned category/entity records.
- Cover mixed cash/card data, multi-allocation, empty buckets, paid state, and special
  exclusions.

### Acceptance

- Every reported total equals the sum of unique contributing installments.
- A category/entity anchored report contains only transactions with that allocation.
- Transfer and Piggy Bank families do not appear as ordinary income/outcome.
- Cash plus card drill-down subtotals equal the displayed combined amount.

### Suggested commit

`feat: report category and entity trends`

## Slice 3 — Category and Entity Trend UI

**Goal:** replace display-only pie behavior with bounded, navigable analysis.

### Deliverables

- Add shared date-range, granularity, paid-state, and direction controls.
- Lazy-load category/entity report sections on their show dashboards.
- Render accessible trend charts and matching textual breakdowns.
- Link each eligible point/breakdown to its exact typed transaction destination.
- Preserve report state across show -> drill-down -> show navigation.
- Remove superseded inline payload construction only after parity coverage passes.

### Acceptance

- URLs restore the same selected report state on refresh and return.
- Stale responses cannot replace newer filter results.
- Charts, text, and drill-downs use identical amounts and ordering.
- Mobile and dark mode remain usable without layout shifts.

### Suggested commit

`feat: connect category and entity trend dashboards`

## Slice 4 — Bank Account Movement

**Goal:** explain one bank account's bounded cash movement and recorded balance
contribution.

### Deliverables

- Add a bank-account movement service over canonical cash rows.
- Report income, outcome, net movement, paid/pending subtotals, and recorded balance
  context without recalculating balances.
- Separate ordinary, transfer/return, Piggy Bank, and generated-projection families.
- Add exact drill-downs and replace the account show's inline chart aggregation.
- Add query-count coverage for an account with many allocations/installments.

### Acceptance

- Only the selected owned account and current context contribute.
- Paid and pending subtotals reconcile with `all`.
- Special families remain visibly distinct from ordinary movement.
- Rendering and fetching perform no writes.

### Suggested commit

`feat: explain bank account movement`

## Slice 5 — User Card Movement

**Goal:** explain one card's spend without collapsing distinct card dates and flows.

### Deliverables

- Add a user-card movement service over canonical card rows.
- Report paid/pending movement by billing period.
- Retain purchase date, installment date, reference closing/due dates, invoice
  identity, advance state, and generated payment identity in drill-down metadata.
- Add exact report links and replace the card show's inline chart aggregation.
- Cover one-off purchases, installments, shifted references, advances, and payments.

### Acceptance

- Billing-period totals reconcile with the exact card-installment destination.
- Purchase date is never presented as reference/due date.
- Advances and generated payments are not counted twice as ordinary card spend.
- Other cards and contexts cannot enter the payload.

### Suggested commit

`feat: explain user card movement`

## Slice 6 — Budget Performance

**Goal:** make every budget number explainable from its canonical matched rows.

### Deliverables

- Extract/reuse canonical budget matching behind a read-only performance service.
- Report definition, actual consumption, remaining value, utilization percentage, and
  period completion.
- Split actual consumption into exact cash/card source subtotals and drill-downs.
- Explain inclusive and first-installment-only behavior in compact report metadata.
- Add empty, overspent, completed-period, inactive, and mixed-source coverage.

### Acceptance

- The report and existing budget calculation agree on matched membership and totals.
- Each actual amount opens only the rows counted by that amount.
- Period completion is date progress, not spending progress.
- Rendering does not recalculate or persist the budget.

### Suggested commit

`feat: add reconciled budget performance`

## Slice 7 — Navigable Transfer and Return Flows

**Goal:** complete the connected layer for non-ordinary movement without changing its
classification.

### Deliverables

- Add exact typed identities and drill-down URLs to KAKASHI-06 transfer, failed-return,
  and Piggy Bank result entries.
- Preserve the existing one-month Monthly Analysis request and payload fields.
- Link sent exchanges, received exchange returns, borrow returns, failed returns,
  contributions, withdrawals, and valuation rows to the correct source records.
- Keep source transactions and generated return/projection records distinguishable.
- Add context-isolation and shared-exchange regression coverage.

### Acceptance

- Ordinary totals remain unchanged.
- Every transfer/Piggy Bank summary can be traced to its source records.
- Generated counterpart rows are not mistaken for user-entered sources.
- Actionable-message behavior and exchange synchronization specs are unchanged.

### Suggested commit

`feat: connect transfer and return analysis`

## Slice 8 — Shared Chart Presentation and Closure

**Goal:** remove the remaining presentation drift after all financial contracts are
stable.

### Deliverables

- Consolidate shared report controls, summary cards, legends, textual lists, and
  loading/empty/error states.
- Consolidate Stimulus fetch and Chart.js lifecycle behavior where the interactions
  are truly identical.
- Remove obsolete inline aggregation and unused chart-controller branches.
- Complete request, service, feature, accessibility, mobile, dark-mode, and query-count
  coverage.
- Produce a manual verification document and closure inventory.
- Run RuboCop, focused suites, and full CI.

### Acceptance

- All migrated reports use one payload vocabulary and presentation language.
- No financial total is calculated in Phlex or JavaScript.
- No stale request, duplicate Chart.js instance, or disconnected controller leaks.
- Full CI passes with explicit mutation-regression coverage.

### Suggested commit

`test: close connected dashboard reporting coverage`

