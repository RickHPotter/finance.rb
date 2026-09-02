# KAKASHI-17 Implementation Slices

## Delivery Rule

Each slice is independently reviewable, covered, RuboCop-clean, and ends with a
focused commit description. Later slices may reuse proven components from earlier
ones, but a slice must not silently broaden financial mutation behavior.

## Slice 1 — Dashboard Drill-down Inventory and Filter Contracts

**Goal:** turn every existing dashboard action into an explicit, testable navigation
contract before changing its URL.

### Deliverables

- Inventory every direct record, collection, allocation, count, chart, and related
  link in the seven existing show views.
- Record source section, visible claim, current URL, expected membership, required
  filter, and return destination.
- Add missing bounded ID/relationship filters to existing collection query builders.
- Extend the corresponding `Navigation::*` allowlists and canonicalization.
- Add request specs proving exact membership and context isolation.

### Acceptance

- No dashboard collection action relies on `search_term` to represent a relationship.
- A crafted cross-context ID/filter returns no foreign records.
- Invalid or oversized filter state falls back to a canonical safe destination.
- Existing KAKASHI-15 navigation specs remain green.

### Suggested commit

`fix: make dashboard drill-down filters exact`

## Slice 2 — Harden Existing Dashboard Links

**Goal:** apply Slice 1 contracts to the existing show pages.

### Deliverables

- Correct collection URLs on cash/card/budget/account/card/category/entity shows.
- Route direct relationships to show pages instead of edit pages.
- Preserve source show as sanitized `return_to`.
- Align action placement, empty labels, mobile links, and generated-reference labels.
- Add the category/entity show merge entry point promised by KAKASHI-18, reusing its
  existing modal/planner flow rather than duplicating merge logic.

### Acceptance

- Each visible count/list/chart action opens exactly the represented records.
- Empty relationships render no misleading enabled collection action.
- Returning from a filtered index restores the source dashboard.
- Merge behavior and KAKASHI-18 planner coverage are unchanged.

### Suggested commit

`fix: harden resource dashboard actions`

## Slice 3 — Investment Show Foundation

**Goal:** add the route, context-scoped controller action, and ordinary Investment
dashboard.

### Deliverables

- Change Investment routes to include `show`.
- Include `show` in `set_investment` with `current_context.investments.find`.
- Add `Views::Investments::Show` using the existing dashboard language.
- Render summary, investment type, account, date/reference month, value, audit link,
  categories/entities from the generated cash projection, and related cash link.
- Point Investment labels on desktop/mobile index rows to show; keep pencil edit.
- Preserve approved `return_to` through show actions.

### Acceptance

- Same-context record renders; other-context record is 404.
- Missing generated cash transaction renders an explicit unavailable state.
- Ordinary Investment is not labelled as Piggy Bank.
- Edit, duplicate, audit, related transaction, and guarded destroy eligibility are
  correct.

### Suggested commit

`feat: add the investment dashboard`

## Slice 4 — Piggy Bank Valuation Investment State

**Goal:** make the Investment dashboard truthful for valuation adjustment rows.

### Deliverables

- Add the valuation-adjustment badge and amount terminology.
- Link the target Piggy Bank return transaction.
- Add exact sibling-valuation collection link using
  `piggy_bank_return_cash_transaction_id`.
- Show calculated target projection total where useful.
- Cover missing/closed targets and destroy eligibility without rendering side effects.

### Acceptance

- Valuation rows never claim to own a generated cash transaction.
- Sibling link contains only valuation rows for that return and context.
- Rendering does not update the projection, balances, audit rows, or timestamps.

### Suggested commit

`feat: explain piggy bank valuation investments`

## Slice 5 — Subscription Show Foundation

**Goal:** add the route, scoped show action, summary, allocations, and live transaction
sections.

### Deliverables

- Change Subscription routes to include `show`.
- Include `show` in context-scoped `set_subscription`.
- Add `Views::Subscriptions::Show`.
- Render lifecycle, derived totals, allocation links, counts, open transactions, and
  paid history.
- Point Subscription labels and cash/card subscription relationship links to show.
- Add edit, audit, add transaction, attach existing, and guarded destroy actions.

### Acceptance

- Cash and card rows link to their correct show types.
- A live record appears exactly once in open or paid history.
- Totals include both live cash and card relationships.
- Other-context subscriptions and transactions are never exposed.

### Suggested commit

`feat: add the subscription dashboard`

## Slice 6 — Subscription Lifecycle Transitions

**Goal:** expose safe status actions without passing a partial payload through the
nested edit action.

### Deliverables

- Add a dedicated Subscription lifecycle member endpoint.
- Permit only `pause`, `resume`, `finish`, and `reopen` events.
- Lock and reload the Subscription inside the transition.
- Enforce the transition matrix in the service/controller boundary.
- Preserve categories, entities, linked transactions, counts, and derived total.
- Add confirmation for Finish and Reopen if the shared action pattern requires it.

### Acceptance

- Status-only actions do not clear allocations or rewrite nested transactions.
- Invalid event/state pairs are rejected with no mutation.
- Concurrent transitions resolve from locked current state.
- The dashboard refreshes with the correct next actions.

### Suggested commit

`feat: add safe subscription lifecycle actions`

## Slice 7 — Detached Subscription History

**Goal:** explain transactions that were previously attached without guessing.

### Deliverables

- Add a read-only query/service over context-owned `AuditVersion` transitions.
- Identify cash/card records whose historical `subscription_id` equals the source
  subscription and whose current relationship no longer does.
- Deduplicate repeated detach/reattach cycles; current live membership wins.
- Present live links for existing records and audit-only tombstones for destroyed rows.
- Paginate or cap the section using a deterministic policy if the audit set is large.

### Acceptance

- Description/category/entity lookalikes without audit evidence are excluded.
- Reattached transactions appear only in the live section.
- Cross-context historical identities are excluded.
- Rendering the history is read-only and bounded.

### Suggested commit

`feat: show detached subscription history`

## Slice 8 — Dashboard Regression and Navigation Closure

**Goal:** close the feature with cross-dashboard coverage and visual consistency.

### Deliverables

- Complete request specs for both new shows and every corrected exact URL.
- Add feature coverage for show -> filtered index -> edit/action -> return.
- Cover mobile rendering, empty relationships, generated rows, and guarded actions.
- Run `bin/rubocop -A`, focused request/service/feature specs, then the full suite.
- Update the sprint docs if implementation discoveries change a locked decision.

### Acceptance

- Every dashboard action has a request-level membership assertion.
- Every show lookup is context-scoped.
- No actionable-message specs or behavior change.
- Full suite passes.

### Suggested commit

`test: close resource dashboard navigation coverage`

