# JIRAIYA-05 Implementation Slices

## Slice 1. Current-Surface Audit

### Goal

Freeze the real baseline before changing UX primitives.

### Deliverables

- list every remaining `HotwireCombobox` dependency in live form flows
- identify form-specific date/datetime behavior
- identify repeated-entry entry points by model
- document `BulkActionBar` current inputs and missing aggregates

### Exit Condition

The repo has a concrete map of what is still transitional and what is already
standardized.

## Slice 2. Combobox Consolidation

### Goal

Make `RubyUI::Combobox` the single supported combobox primitive for the in-scope
entry flows.

### Strategy

Do this incrementally.

Phase 1:

- migrate the easy surfaces first
- target forms where combobox selections are not being actively manipulated by
  Stimulus/custom JavaScript after selection
- infer the first batch from the current repo instead of overplanning it before the
  work starts

Phase 2:

- migrate the complex surfaces later
- especially `cash_transactions` / `card_transactions` forms and anything else still
  coupled to `reactive_form_controller.js`
- build the missing `RubyUI::Combobox` behavior that those forms need instead of
  trying to prebuild everything at once

### Deliverables

- phase 1:
  - remove `HotwireCombobox` usage from easy in-scope forms first
  - prove the migration pattern on forms that are not JS-driven after selection
- phase 2:
  - remove legacy combobox coupling from `reactive_form_controller.js`
  - migrate card/cash/budget/investment entry surfaces that still depend on old
    combobox internals
  - add the missing `RubyUI::Combobox` behaviors exposed by those migrations
- finalization:
  - remove the old package import from `app/javascript/controllers/application.js`
  - remove the `hotwire_combobox` gem/package completely at the end of the slice

### Risks

- current reactive-form logic relies on old controller internals, not only events
- category/entity insertion flows may regress if the replacement is too literal

### Compatibility Direction

Prefer extending `RubyUI::Combobox` with the minimum features/events needed for the
existing Stimulus controllers to keep working during migration. The first goal is a
seamless replacement path, not a deep redesign of combobox behavior.

### Validation

- manual pass is mandatory after each migration batch
- add request specs only when they protect real server-driven behavior that the
  migration can regress
- do not add feature specs

## Slice 3. Chain Creation / Duplication Workflow

### Goal

Reduce the number of actions required to create similar transactions in sequence.

### Deliverables

- add explicit duplication for `CashTransaction`
- add explicit duplication for `Investment`
- keep `Budget` and `Subscription` out of this slice
- implement chain controls in the form surface:
  - localized `Create more` / `Duplicate more` checkbox
  - localized finish-chain button
- define the carry-over behavior for both chain modes:
  - clean `new`
  - `duplicate`
- make each newly created record become the next duplication sample inside the chain
- finish the chain by returning to index with the created records in view through
  the relevant `*_installment_id`
- keep date/price/installment behavior explicit
- avoid silently carrying over fields that create wrong financial structure

### Notes

`CardTransaction#duplicate` exists today, but it should be treated as a baseline
reference for the new chained duplicate behavior.

The intended behavior is:

1. clean `new`
   - start mostly blank
   - preserve only the minimum required context between rounds
   - for card transactions, `user_card_id` is the obvious preserved example
   - each new round should stay clean as well

2. duplicate chain
   - round 1 starts from the current duplicate sample behavior
   - each new saved record becomes the source for the next round
   - for cash transactions, mirror current `CardTransaction#duplicate` behavior as
     closely as possible

3. chain state UI
   - the form should clearly indicate the chain state
   - reuse the existing operation label area for:
     - `Chain Creating`
     - `Chain Duplicating`

4. end-of-chain
   - render the index with the created family visible instead of dropping the user
     into an unrelated default index state
   - default to a filtered landing based on the created family
   - highlighting is optional and can be added later if useful

### Model-Specific Defaults

- `Investment` duplication:
  - preserve everything except `price` and `date`
  - duplicated investment price should reset to zero
  - duplicated investment date should advance to the next day
  - focus should land on price

### Optional Add-On

If save/render latency is noticeable, add a reusable skeleton loading state during
chain creation. This is not required to start the slice, but it is a good fit here.

## Slice 4. Date and Datetime UX

### Goal

Make date entry consistent across desktop and mobile.

### Deliverables

- optimize for fast typed entry and faster keyboard navigation on desktop first
- reduce dependence on segmented native `datetime-local` interaction
- make 24-hour input behave consistently inside the app
- define where the app should use `date`
- define where the app should use `datetime-local`
- preserve the existing date when the user edits only the time portion
- keep mobile/PWA conservative until the desktop contract is proven better

### Guardrail

Do not change date semantics casually. This slice is about UX and input primitives,
not about mutating the financial meaning of existing timestamps.

### Explicit Non-Goal

Do not start this slice by building a bespoke calendar/clock UI. That can be
revisited later if typed entry plus conservative mobile fallback still feels bad.

Also do not start by adding shortcut-token grammar. First make the normal keyboard
editing flow fast enough for heavy users.

## Slice 5. Bulk Action Feedback

### Goal

Make bulk actions easier to understand before confirmation.

### Deliverables

- extend `BulkActionBar` beyond selected count
- show aggregated selected price in the bar
- communicate obvious action constraints before the modal opens
- allow all rows to be selectable even when some bulk actions become unavailable
- disable pay/transfer when the current selection contains ineligible rows
- support shift-click range selection
- add a bar-level `Select all` that covers all currently rendered rows across the
  full visible index page, not only one month-year group
- add `Add to Subscription` as a bulk action on cash/card transaction indexes
- open a subscription-selection modal before confirming that action

### Candidate Aggregates

- total selected amount
- selected installment count
- whether the selection mixes paid and unpaid rows
- whether the selection spans multiple months/accounts

### Eligibility Notes

- not every transaction kind should be eligible for `Add to Subscription`
- cash-side obvious exclusions today:
  - `CARD PAYMENT`
  - `CARD ADVANCE`
  - `INVESTMENT`
- card transactions are expected to be broadly eligible
- if the current selection mixes eligible and ineligible rows, disable the action for
  the whole selection
- this same whole-selection disable rule should apply to pay/transfer

### Implementation Note

- `Add to Subscription` should attach to an existing subscription, not create a new
  one from the bar
- the base write path is a direct `subscription_id` update on the selected records
- no job is required for the base version unless later scale/latency proves it
  necessary

### Feedback Rule

Keep invalid actions visible but disabled, and show a short reason for the disabled
state either inline in the bar or through a tooltip/hover affordance.

## Slice 6. Optional Partial `PayMultiple`

### Goal

Only if explicitly approved later: allow partial bulk payment where the rules are
fully deterministic.

### Status

Not part of the default `JIRAIYA-05` implementation plan.

### Gate

Do not start this slice unless the previous slices are done and the allocation rules
are written first.

## Cross-Slice Invariants

These rules should remain true throughout JIRAIYA-05:

1. JIRAIYA-04 financial-safety rules remain intact.
2. Bulk or chained entry must not bypass paid-history guards.
3. Exchange/shared-return flows must keep the canonical reference chain model.
4. UX shortcuts must not create hidden structural mutations.

## Recommended Execution Order

1. Slice 1: current-surface audit
2. Slice 2: combobox consolidation
3. Slice 3: repeated-entry workflow
4. Slice 4: date and datetime UX
5. Slice 5: bulk action feedback
6. Slice 6: optional partial `PayMultiple`

## What Is Still Missing Before Implementation?

From a backend/safety standpoint: nothing critical.

The remaining missing items are product decisions:

- the first-pass model scope
- whether partial `PayMultiple` stays out

That means implementation can start as soon as those product choices are locked.
