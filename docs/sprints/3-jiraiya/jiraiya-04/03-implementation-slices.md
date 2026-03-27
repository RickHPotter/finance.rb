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

### Status

- Implemented.
- Shared rule predicates now live in `HasFinancialSafetyRules`, with exchange-specific projection predicates kept separate on `Exchange`.

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

### Status

- Implemented.
- Unsafe paid-history rewrites are now blocked at the model/concern layer for:
  - direct cash/card transaction updates and destroys
  - linked subscription mutation paths
  - card-advance linked cash flows
  - exchange mirrored cash projections

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

### Status

- Implemented.
- Blocked writes now return `422 Unprocessable Content` consistently.
- Replay/apply failures remain unapplied.
- Turbo failure branches now surface:
  - the exact historical-lock reason
  - the recommended workaround from the workaround matrix

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
- cross-user paid / not-paid toggles on the shared return flow must synchronize through assistant messages instead of remaining local-only

### Test target

- concern specs
- request specs
- clone/replay regressions if the persistence shape changes behavior
- message-sync regressions for paid / not-paid propagation between the two users

### Status

- Implemented.
- The exchange-return persistence shape has already been normalized in the exchange concern toward:
  - many `Exchange`
  - one shared exchange-return `CashTransaction`
  - many mirrored `CashInstallment`
- Bidirectional paid / not-paid synchronization is now implemented for the shared return flow:
  - `paid` and `not paid` propagate to the counterpart mirrored installment
  - assistant messages record the remote paid-state change
  - scenario-aware routing is preserved for derived contexts
  - counterpart-missing cases fail clearly instead of diverging silently
- Shared return paid toggles now have a narrow safety-rule carve-out:
  - pure paid-state toggles are allowed
  - structural/date/price/allocation rewrites remain blocked
- Pending paid-state notifications are now explicitly acknowledgeable in the assistant thread:
  - they remain pending until the receiver clicks `Ok`
  - acknowledging them removes them from the pending assistant view immediately
- Mirrored unpaid `EXCHANGE RETURN` structural edits now emit the normal actionable counterpart `update` message after reverse-syncing back into the canonical exchange source.
- Focused exchange concern/model/request coverage is green for the normalized structure and paid-state synchronization.

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
- guidance for delayed-entry catch-up sequencing when the user returns after several days away
- guidance for narrow historical correction cases, such as card date fixes that keep the same billing cycle and cash month-boundary fixes that need confirmation

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
- delayed-entry catch-up ordering reconciliation with explicit confirmation
- paid `CardTransaction` date correction with the same `ref_month_year`
- paid `CashTransaction` month-boundary correction with explicit confirmation
- historical cleanup scenarios that lack a safe compensating-entry workaround

### Status

- Implemented narrowly for the two approved correction paths.
- Paid `CardTransaction` history can now be corrected with explicit confirmation when the change keeps the same `ref_month_year`.
- Paid `CashTransaction` history can now be corrected with explicit confirmation when the change is a delayed-entry month-boundary move between adjacent periods.
- Paid `CashTransaction` can now be marked back to `not paid` with explicit confirmation when the paid installment is still in the current month.
- The confirmation is form-bound:
  - first submit returns a specific confirmation-required failure
  - the rerendered form exposes an explicit confirmation submit
  - no broad unsafe bypass was added

## Post-Slice Stabilization

### Goal

Close the regressions exposed by the maintained suite after Slices 1-6 were implemented.

This was not a new product slice.
It was a hardening pass to make the rule set, supporting factories, and indirect write paths coherent.

### What was stabilized

- the local test runner path:
  - `.env.test` now carries the test database credentials expected by `config/database.yml`
  - the maintained suite is expected to run with `.env.test` loaded
  - in constrained environments, local PostgreSQL access may still require elevated execution
- paid-history date boundaries:
  - paid installment boundary detection now uses DB date casting instead of Ruby-side timestamp coercion
- card invoice projection safety:
  - moving an unpaid `CardTransaction` into an already-paid invoice cycle is now blocked explicitly
  - same-invoice corrections no longer trip the projection guard falsely
- generated projection cleanup:
  - orphaned generated `CashTransaction` rows are now removed correctly for:
    - `Investment`
    - `CARD ADVANCE`
    - `CashTransactable`-backed projection switches
- shared paid-state synchronization:
  - direct counterpart linkage is now recognized even when message history is absent
  - reverse `reference_transactable` linkage is enough to identify the counterpart flow
- nested subscription validation:
  - missing-card / missing-bank-account nested errors are preserved instead of being cleared by later validation calls
- user-card payment schedule maintenance:
  - unpaid exchange-return maintenance now updates:
    - mirrored `CashInstallment`
    - shared return `CashTransaction`
    - bound `Exchange`
  - these maintenance updates are applied atomically without the exchange callback writing stale dates back
  - datetime normalization uses `end_of_day` so persisted dates remain stable under timezone conversion
- assistant-thread paid-state handling:
  - `notification:paid_state` no longer shows destroy-state badges
  - it now has an explicit `Ok` acknowledgment action
  - it remains in the pending assistant filter until acknowledged
  - acknowledging it removes it from the pending assistant view immediately through Turbo
- mirrored exchange-return counterpart notifications:
  - structural unpaid edits on mirrored `EXCHANGE RETURN` installments now create the normal actionable counterpart `notification:update`
  - pure paid-state changes remain on the dedicated `notification:paid_state` path
- exchange projection rebuild maintenance:
  - mirrored projection installment rebuild now replaces derived installments cleanly instead of stacking duplicate rows under repeated sync passes

### Validation result

- maintained suite executed green:
  - `spec/models`
  - `spec/concerns`
  - `spec/requests`
- result:
  - `526 examples, 0 failures`
- follow-up shared-return hardening also landed after the main stabilization pass:
  - counterpart resolution now accepts:
    - direct reverse linkage
    - structurally matched shared-return pairs
    - duplicate-family resolution by stable creation order when signatures collide
  - bulk shared paid-state notification deduplication now keys by the mirrored transaction too,
    so distinct mirrored transactions do not collapse into one assistant message
  - mirror paid-state synchronization now runs through `SyncSharedPaidStateJob`
    using Solid Queue, with deadlock retries for concurrent bulk-pay cases
  - the maintained request coverage for shared-return flows was expanded to cover:
    - card-origin shared returns
    - reimbursement-origin shared returns
    - counterpart-missing failure behavior
    - source reimbursement transaction isolation from the shared return pair

## Retroactive Repair Passes

The normalized rules above were not enough on their own for historical data.

Two explicit backfill steps were added for legacy standalone `EXCHANGE RETURN` rows:

1. projection sync:
   - legacy mirrored `cash_installments` are the source of truth
   - linked standalone monetary `Exchange` rows are rewritten to match them
   - documented in `05-legacy-exchange-return-normalization.md`
2. consolidation:
   - old one-installment standalone exchange-return cash transactions are merged into
     one shared return transaction with many installments
   - documented in `06-legacy-exchange-return-consolidation.md`

These two steps are part of the practical rollout of Slice 4, even though they were
implemented after the normalized write model itself.

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

## Current Position

`JIRAIYA-04` is currently through Slice 6, with Slice 4 rollout/backfill follow-up completed.

Remaining follow-up work should stay narrow:

- delayed-entry catch-up ordering reconciliation beyond the explicit month-boundary case
- any additional override candidate only after real usage proves the workaround is insufficient
- any future optimization of shared-return bulk pay should be performance-driven,
  not a new rules change

The next implementation step is no longer “whether to finish Slice 4”.

It is:

1. move to Slice 5 and improve workaround-supporting UX where the new safety walls still feel abrupt
2. then move to Slice 5 workaround-supporting UX

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
