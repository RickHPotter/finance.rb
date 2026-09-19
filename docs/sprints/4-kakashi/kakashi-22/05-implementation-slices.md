# KAKASHI-22 Implementation Slices

## Overview

KAKASHI-22 adds safe snapshot reconciliation to the existing Piggy Bank graph. Work is
split into reviewable slices and stops after each slice for review. Every implementation
slice must be covered, RuboCop-clean, and end with a proposed commit description.

The bank-product inputs P1 and P2 are approved: use the observed current net redeemable
total and propose an editable contribution-date-plus-30-days IOF-free date.

## Slice 1: Freeze Existing Piggy Bank Valuation Semantics

Status: complete as of 2026-09-15. The regression suite now freezes persisted grouped
baselines, signed valuation arithmetic, several immutable paid splits, adjustment-month
reporting, and real operation-wide rollback of a newly created linked valuation. The
focused model/reporting/rollback run passed with 41 examples and no production behavior
changed.

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

Status: complete as of 2026-09-15. `PiggyBankReconciliations::Preview` now resolves only
the supplied user's current-context generated return, validates canonical contribution,
valuation, parent, and installment arithmetic, calculates against the unpaid projection,
and returns immutable ready/no-op/invalid plans. Its deterministic digest binds the
observation, calculation, configuration, and complete relevant graph. The affected
Piggy Bank regression suite passed with 115 examples and no writes are performed.

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

Status: complete as of 2026-09-18. `PiggyBankReconciliations::Apply` locks the Piggy Bank
return-group boundary, recalculates against the fresh graph state, rejects stale preview
digests, and applies nonzero reconciliation deltas atomically. A zero delta returns a
successful no-op with zero writes. The existing `piggy_bank_sync` projection logic
preserves paid installments and updates only the unpaid remainder. PostgreSQL
concurrency and failure-injection specs verify deterministic retry rejection and atomic
rollback. The affected Piggy Bank suite passed with 26 focused service examples and 67
overall examples.

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

Status: complete as of 2026-09-18. Reconciliation apply operations record complete
scalar metadata on the root `AuditOperation` and attribute projection changes to
`piggy_bank_sync`. The existing guarded rollback engine preview is verified as
previewable without gaps; rollback restores the exact pre-apply canonical business graph
across positive, negative, and partial-withdrawal scenarios while deleting the created
investment. Later mutations to the valuation, return transaction, or installments
reliably produce conflicted states that block rollback. Rollback failure and integrity
failures abort atomically. The dedicated rollback suite passed with 8 examples and the
full affected Piggy Bank suite passed with 75 examples.

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

Status: completed on 2026-09-18. Added narrow nested routes for
`resource :piggy_bank_reconciliation, only: %i[new create]` with `post :preview`. Added
`PiggyBankReconciliationsController` with `new`, `preview`, and `create` (apply) actions.
Built localized Phlex views (`Views::PiggyBankReconciliations::New` and
`Views::PiggyBankReconciliations::PreviewCard`) and `PiggyBankReconciliation` ActiveModel
model. Integrated `piggy_bank_return_section` and header action on `Views::CashTransactions::Show`
for open returns. Verified write-free preview, atomic apply, zero-change noop, stale
digest rejection, double-submit protection, stacked failure notifications on 422,
404 foreign scoping, safe return_to, Turbo and HTML navigation, and mobile/dark mode
compliance in 21 request specs. All 55 reconciliation specs pass.

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

Status: completed on 2026-09-19. Added nullable `PiggyBank#iof_exempt_on` (`date`) column
and index. Proposes default of source contribution date plus 30 calendar days for new
contributions without calculating IOF money, while allowing full editing or clearing. Added
permitted strong param in `CashTransactionsController` and form input in
`Views::EntityTransactions::FieldsSheet`. Enhanced both return dashboard
(`Views::CashTransactions::Show`) and contributions sheet
(`Views::PiggyBanks::ContributionsSheet`) to show each lot's contribution date, baseline,
availability date, and waiting/available/not_recorded status badge. Verified independent
clocks for grouped contributions, nullable preservation of legacy records without backfill,
paid-history locking, and that availability changes do not move return date, return price,
or cash installments. Full suite of 89 Piggy Bank model, service, and request specs passes.
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
