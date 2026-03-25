# JIRAIYA-04 Implementation Slices

## Purpose

`JIRAIYA-04` should be implemented in small rule-driven slices.

This feature touches the financial write model at the center of the app.
If implemented too broadly at once, it will become difficult to validate and difficult to unwind.

This document converts the planning rules into an execution order.

## Slice 1. Rule Predicates

### Goal

Encode the safety rules as explicit domain predicates before blocking any UI flow.

### Expected outputs

Add rule methods around:

- paid-history detection
- installment-boundary detection
- structural-edit permission
- destroy permission
- exchange-sync protection

Examples of expected predicate names:

- `has_paid_history?`
- `latest_paid_installment_date`
- `can_edit_unpaid_future_installments?`
- `can_change_allocation?`
- `can_destroy_with_history?`
- `exchange_projection_locked?`

### Primary files

- `CashTransaction`
- `CardTransaction`
- installment concerns
- exchange concerns
- supporting rule objects if extraction becomes cleaner

### Test target

- model specs only
- no controller work yet

## Slice 2. Domain Write Guards

### Goal

Move from passive predicates to enforced write protection.

### Scope

Block unsafe writes in:

- transaction update paths
- installment update paths
- exchange mutation paths
- destroy paths

### Rule

The model/service layer should be the source of truth.
Controllers should not be the only protection layer.

### Test target

- model specs
- concern specs
- service specs where the write path is service-driven

## Slice 3. Request-Level Failure Behavior

### Goal

Make blocked operations fail clearly at the request layer.

### Expected behavior

- rejected updates do not partially persist
- rejected destroys do not partially cascade
- replay/apply failures stay unapplied
- the response surface can explain why the operation failed

### Test target

- request specs for:
  - `CashTransactionsController`
  - `CardTransactionsController`
  - bulk installment flows
  - actionable-message apply flows

## Slice 4. Exchange Normalization

### Goal

Replace the current exchange-return fan-out with the normalized structure:

- one paying `EntityTransaction`
- many `Exchange`
- one exchange-return `CashTransaction`
- many mirrored `CashInstallment`

### Scope

Change the domain shape for:

- exchange creation
- exchange update
- exchange destroy
- exchange cloning / replay assumptions where needed

### Invariant

For V1:

- `Exchange` is canonical
- return-side `CashInstallment` mirrors `Exchange`
- direct structural edits on mirrored installments remain blocked

### Test target

- concern specs
- request specs
- clone/replay regressions if the persistence shape changes behavior

## Slice 5. Workaround-Supporting UX

### Goal

Support the blocked-case workaround paths defined in the workaround doc.

This is not broad UX redesign.
It is only the minimal UX needed so blocked flows are usable.

### Examples

- clearer error surfaces
- guidance toward compensating entries
- guidance to edit exchange side instead of mirrored installment side
- guidance to split future plan into a new transaction where appropriate

### Test target

- request specs first
- feature/system coverage only where absolutely needed

## Slice 6. Warn-Only / Override Candidates

### Goal

Implement only the smallest explicit warning/override subset that proves necessary after the hard blocks are in place.

### Important constraint

Do not add a generic bypass.

If an override is introduced, it should be:

- explicit
- narrow
- traceable
- backed by tests

### Likely candidates

- paid date correction
- crossing the latest paid boundary
- historical cleanup scenarios that lack a safe compensating-entry workaround

## Slice 7. Partial `PayMultiple`

### Goal

Add partial payment support only after the safety boundaries are stable.

### Rule

Partial payment is acceptable only where allocation is deterministic.

Avoid:

- ambiguous residual distribution
- hidden installment rewriting
- behavior that bypasses the same paid-history rules

### Test target

- service specs for allocation logic
- request specs for bulk payment behavior

## Cross-Slice Invariants

These rules must remain true throughout implementation:

1. paid history is never silently rewritten
2. blocked mutations do not partially persist
3. context isolation still holds
4. assistant replay/apply cannot bypass safety rules
5. exchange and mirrored return installments never drift structurally

## Recommended Execution Order

1. Slice 1: rule predicates
2. Slice 2: domain write guards
3. Slice 3: request-level failure behavior
4. Slice 4: exchange normalization
5. Slice 5: workaround-supporting UX
6. Slice 6: narrow override candidates if still necessary
7. Slice 7: partial `PayMultiple`

## Why This Order

- rules should exist before enforcement
- enforcement should exist before UX
- exchange normalization is large enough to deserve its own slice after the first safety boundaries are already encoded
- partial payment should be late because it depends on stable mutation semantics

## Done Criteria

`JIRAIYA-04` should be considered implemented when:

- unsafe historical rewrites are blocked at the domain level
- blocked request flows fail clearly and consistently
- exchange-return persistence is normalized
- workaround paths are documented and minimally supported
- the focused safety spec matrix is in place
