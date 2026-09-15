# KAKASHI-22 Implementation Slices

## Overview

KAKASHI-22 adds safe snapshot reconciliation to the existing Piggy Bank graph. Work is
split into reviewable slices and stops after each slice for review. Every implementation
slice must be covered, RuboCop-clean, and end with a proposed commit description.

Development begins only after approval gates P1 and P2 in the decisions document are
resolved.

## Slice 1: Freeze Existing Piggy Bank Valuation Semantics

1. Characterize grouped baseline, signed linked Investments, parent return total, paid
   history, and unpaid projection with executable examples.
2. Add explicit regression coverage for several paid splits followed by positive and
   negative valuation changes.
3. Freeze current ordinary Investment, Monthly Analysis, Piggy Bank Health Check,
   context isolation, and rollback behavior.
4. Document any implementation mismatch discovered before adding a new write path.

Acceptance:

- current grouped-return arithmetic is executable and unambiguous;
- partial-payment examples prove that the current bank balance corresponds to the
  unpaid projection rather than the lifetime parent total;
- no production behavior changes in this slice.

Commit: `spec: characterize piggy bank valuation reconciliation`

## Slice 2: Add a Write-Free Reconciliation Preview

1. Introduce a focused value object/service that resolves a canonical owned return
   group and calculates entirely in integer cents.
2. Validate observation date/value, graph integrity, group state, and required
   configuration.
3. Return recorded remaining value, observed value, signed delta, resulting lifetime
   total, paid total, and a deterministic graph digest.
4. Represent zero delta as an explicit no-change result.
5. Add service specs for positive, negative, zero, invalid, foreign, partially paid,
   fully settled, and broken-graph cases.

Acceptance:

- preview performs no domain or audit writes;
- calculations use unpaid installments after partial withdrawal;
- repeated preview of an unchanged graph returns the same digest.

Commit: `feat: preview piggy bank net reconciliation`

## Slice 3: Apply Reconciliation Atomically

1. Add an apply service using one database transaction and a deterministic lock at the
   Piggy Bank return-group boundary.
2. Recalculate after locking and reject stale preview digests before mutation.
3. Create one linked Investment for a nonzero delta using canonical account/type/date
   defaults.
4. Reuse existing `piggy_bank_sync` projection logic to preserve paid installments and
   replace only the unpaid remainder.
5. Make retry/double-submit behavior deterministic.
6. Add failure injection and PostgreSQL concurrency coverage.

Acceptance:

- one nonzero apply creates one Investment and one correct projection outcome;
- a zero apply creates nothing;
- raced or stale apply creates nothing;
- any validation/synchronization failure restores the entire graph.

Commit: `feat: reconcile piggy bank net value`

## Slice 4: Make Reconciliation Fully Auditable and Reversible

1. Attach stable reconciliation metadata to the root `AuditOperation`.
2. Verify every generated Investment/return/installment version belongs to that one
   operation and uses the expected mutation source.
3. Extend rollback recognition only where the real operation proves a gap.
4. Compare a canonical graph snapshot before apply and after guarded rollback.
5. Cover later conflicts and rollback failure atomicity.

Acceptance:

- a fresh real reconciliation operation is previewable;
- rollback restores exact pre-apply business state;
- later edits block compensation rather than permitting a partial restore.

Commit: `feat: rollback piggy bank reconciliations`

## Slice 5: Deliver the Reconciliation Workflow

1. Add narrow authenticated routes/controller actions for form, preview, and apply.
2. Add the action to the generated Piggy Bank return detail surface.
3. Build a localized Phlex form and comparison preview using shared inputs/components.
4. Retain observation input and show stacked actionable feedback on `422` responses.
5. Handle zero-change success, stale refresh, double submission, `return_to`, HTML, and
   Turbo navigation.
6. Polish mobile, desktop, light, and dark mode without changing the ordinary
   Investment form.

Acceptance:

- the user enters a bank-observed total and never calculates the delta manually;
- the preview makes paid history and the resulting adjustment clear;
- foreign or malformed targets do not leak or mutate data;
- all supported navigation modes return to the authoritative group.

Commit: `feat: add piggy bank reconciliation workflow`

## Slice 6: Track Contribution IOF Availability

1. Add the approved nullable contribution-level availability field and database index
   if its query path warrants one.
2. Apply the approved manual/default initialization rule without calculating IOF money.
3. Add editing/validation through the authoritative contribution/source flow.
4. Show each lot's contribution date, baseline, availability date, and waiting/available
   status on the return dashboard/sheet.
5. Prove that availability changes do not move or revalue return projections.
6. Preserve existing rows without a mandatory backfill.

Acceptance:

- grouped contributions retain independent clocks;
- blank legacy dates remain valid and clearly labelled;
- `return_date` and installments are unaffected by availability changes;
- paid-history and audit conventions govern edits.

Commit: `feat: track piggy bank IOF availability`

## Slice 7: Reporting, Regression, and Manual Closure

1. Verify reconciliation-created deltas in Monthly Analysis and Investment navigation.
2. Cover positive/negative observation-month recognition, partial withdrawal, and
   zero-change absence.
3. Run affected model, service, request, reporting, health-check, audit, and rollback
   suites.
4. Add a manual verification guide for day-30 catch-up, early redemption, partial
   withdrawal, zero change, stale preview, availability lots, localization, mobile,
   and dark mode.
5. Run `bin/rubocop -A` and `bin/ci`.
6. Record delivered behavior, schema/operational notes, test evidence, and deferred
   atomic settlement/structured snapshot work in a closure report.

Acceptance:

- ordinary Investments and Piggy Bank manual deltas retain their existing behavior;
- exchange/actionable-message rules remain unchanged;
- automated and manual matrices agree with the final contract;
- no known implementation leftovers remain undocumented.

Commit: `docs: close piggy bank net reconciliation`

## Deferred Unless an Approval Gate Requires It

- atomic reconcile-and-settle after the bank reveals only a final amount;
- a first-class immutable valuation snapshot table;
- separate structured gross yield, IOF, income tax, or fee entries;
- bank import/integration;
- automatic tax schedules or daily accrual;
- allocation of group valuation across individual contribution lots.
