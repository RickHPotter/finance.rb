# KAKASHI-21 Implementation Slices

## Overview

KAKASHI-21 adds a required merge-mode decision to the existing reference merge and
implements a forward, sequence-preserving installment reallocation. Each slice keeps
the legacy combine result stable while moving the write path toward one planned,
audited, rollbackable operation.

## Existing Baseline

The six original slices below substantially landed before formal KAKASHI-21 activation,
primarily in commit `6660b1a5`, with later production-driven corrections preserving
installment dates, reducing invoice callback churn, retaining explicitly unpaid invoice
state at the due-date boundary, and preferring the unpaid shifted invoice graph.

They describe the intended product and remain acceptance requirements, but they must
not be replayed as a rewrite. Development starts with the five reconciliation slices
after the original plan. Each slice is independently reviewable, covered,
RuboCop-clean, and ends with a proposed commit description. Development stops after
each slice for review.

## Slice 1: Add the Explicit Merge Decision

1. Add stable `merge_mode` values for `combine_into_target` and
   `reallocate_installments` at the domain boundary.
2. Add a required localized choice with consequence text to
   `Views::References::Merge`.
3. Permit and validate `merge_mode` in `ReferencesController`.
4. Reject missing/unknown values with `422 Unprocessable Content` and the existing
   merge form; do not mutate data.
5. Hide or disable reallocation when target is not the month immediately after source,
   while enforcing the same rule in the service.
6. Update existing request/service callers to choose combine mode explicitly.

Acceptance:

- both choices render in HTML and Turbo responses
- no choice is inferred from the card issuer
- existing combine-mode specs retain their current financial assertions
- invalid mode and backward reallocation create no audit operation or domain mutation

Commit: `feat: choose user card reference merge mode`

## Slice 2: Extract a Deterministic Reallocation Plan

1. Separate validation/planning from mutation in `Logic::References` or focused
   `ReferenceMerges` collaborators.
2. Resolve source/target references and unpaid invoices inside the supplied context.
3. Build the shifted bucket range from source through the latest persisted affected
   installment or card-bound monetary exchange.
4. Resolve each destination reference/invoice and mark missing tail graph records for
   canonical creation.
5. Classify paid/locked rows, foreign rows, duplicate canonical projections, and
   unsupported graphs before apply.
6. Produce a deterministic lock set ordered by model and ID and a mutation order from
   latest bucket to source.

Acceptance:

- the plan maps each affected row from `YYYY-MM` to exactly `next_month`
- gaps remain calendar gaps rather than collapsing the sequence
- card/context isolation is expressed in every base relation
- a multi-installment transaction and independent one-installment purchases share the
  same bucket-based rule
- unsafe history yields a reasoned failure with no writes

Commit: `refactor: plan reference merge reallocation`

## Slice 3: Reallocate Installments and Rebuild Invoices

1. Open one database transaction and acquire the plan's locks.
2. Replan after locking and reject stale membership.
3. Create missing destination references/invoices through canonical domain paths.
4. Reassign card installments in descending bucket order, updating destination
   month/year and invoice association while preserving every original installment date.
   Route invoice callbacks through the explicit destination reference instead of
   inferring it from that preserved date.
5. Rebuild every affected invoice from final membership.
6. Remove empty source/intermediate invoices and finally destroy the source reference.
7. Keep projection synchronization proportional to occupied buckets: establish each
   destination invoice through one representative installment, audit the remaining
   reassignments without projection callbacks, and synchronize the final aggregate once.
8. Preserve the existing target-closing-boundary merge behavior.
9. Recalculate balances once from the earliest affected billing date after integrity
   checks pass.

Acceptance:

- the 12-installment January–December example ends in January 2027
- installment IDs, parent transaction IDs, numbers, counts, and monetary values do not
  change
- an August 12 one-installment purchase routed from September into October remains
  dated August 12
- multi-installment purchase/schedule dates remain consecutive without a false skipped
  month after the first shifted installment
- one canonical invoice exists per occupied destination bucket
- a failure during any bucket restores the entire pre-apply state

Commit: `feat: reallocate card installments across references`

## Slice 4: Shift Card-Bound Exchanges and Projections

1. Extend KAKASHI-11 selection from only the source bucket to the full reallocated
   bucket range.
2. Move matching monetary card-bound exchanges to their next canonical reference date.
3. Synchronize emptied and populated projection buckets through the existing exchange
   projection domain service/concern.
4. Merge legacy duplicate projections deterministically only where current safety rules
   already allow it.
5. Include exchange/projection failures in the outer reference-merge transaction.

Acceptance:

- every shifted exchange matches its destination invoice reference
- source/empty projection rows are removed and destination projections have exact sums
- unrelated cards, contexts, non-card-bound exchanges, and unrelated cash projections
  remain byte-for-byte unchanged in their business attributes
- paid projection safety remains fail-closed or confirmation-gated as defined by
  KAKASHI-08/KAKASHI-11

Commit: `feat: reallocate reference merge exchange projections`

## Slice 5: Make the Full Operation Auditable and Rollbackable

1. Wrap both merge modes in one grouped `Audit::Operation` nested inside the business
   transaction.
2. Add scalar merge metadata: mode, card/context IDs, source/target, and affected range.
3. Replace any unaudited bulk write of business attributes with audited mutations that
   still avoid callback storms.
4. Extend reference-merge recognition in `Audit::Rollback::Adapters::Reference`,
   `CashTransaction`, `Installment`, `Exchange`, and related dependency planning for the
   multi-bucket graph and created tail.
5. Declare dependencies for both the before and after invoice association of every moved
   `CardInstallment`.
6. Ensure rollback destroys merge-created tail rows, recreates destroyed source rows
   with their original IDs, restores moved rows, then runs canonical recalculations.
7. Keep unknown graph shapes read-only; do not introduce partial or forced rollback.

Acceptance:

- a successful reallocation produces exactly one committed merge operation containing
  every financial mutation
- its fresh rollback preview is `previewable` (or only requires the already-documented
  paid-history confirmation), never read-only due to an unsupported known graph
- applying rollback restores a canonical pre-merge graph snapshot
- one compensation/integrity failure rolls back both business restoration and the new
  rollback audit versions
- later edits to any affected row make the preview conflicted

Commit: `feat: rollback reference installment reallocations`

## Slice 6: Regression Matrix and Operational Hardening

1. Add focused service specs for planning, application, locking, and failure injection.
2. Add request specs for choice validation, Turbo/HTML responses, navigation, and
   context isolation.
3. Add rollback adapter specs based on real reallocation operations rather than
   synthetic version fixtures.
4. Add snapshot helpers that compare the complete affected graph before merge and after
   compensation, excluding immutable audit rows and operational timestamps.
5. Exercise PostgreSQL uniqueness/locking behavior for concurrent merges on the same
   card and independent merges on different cards/contexts.
6. Run `bin/rubocop -A` after each edit batch, the focused specs after each slice, then
   the affected request/service/audit suites and `bin/ci` before completion.

Acceptance:

- combine behavior and KAKASHI-11 regressions remain green
- year boundaries, gaps, existing/missing tail graphs, one-off purchases, multiple
  transactions, exchanges, and rollback are covered
- concurrent same-card applies serialize or reject cleanly without duplicate invoices
- no partial merge or rollback state can be observed after an injected failure

Commit: `spec: harden reference merge reallocation`

## Reconciliation and Closure Slices

### Slice 7: Characterize the Inherited Two-Mode Contract

1. Inventory the exact current result of combine and reallocate modes at the public
   service and HTTP boundaries.
2. Add or tighten regression examples before refactoring any financial mutation.
3. Freeze date preservation, installment identity/economics, invoice membership,
   exchange projection ownership, context/card isolation, and operation metadata.
4. Prove missing/invalid modes and invalid dates fail without business or audit writes.
5. Record the production-driven fixes that are already part of the supported baseline.
6. Assert that reference merging does not introduce a new actionable-message policy or
   change established send/receive/auto-apply behavior.

Acceptance:

- both modes have executable before/after graph expectations
- known behavior is protected before shared-boundary changes begin
- gaps between the written contract and implementation are explicit test failures or
  documented follow-up work, never silently normalized

Commit: `spec: characterize user card reference merge modes`

### Slice 8: Harden the Shared Merge Boundary and Locks

1. Give both modes a consistent result/error contract without changing their successful
   financial outcomes.
2. Normalize and validate dates before lookup so malformed requests fail closed rather
   than raising an unhandled parsing exception.
3. Serialize mutations at the selected user-card/context boundary, then resolve and
   lock the complete affected graph in deterministic order.
4. Replan after the boundary lock and reject stale or phantom membership before the
   first mutation.
5. Bring combine mode under the same stale-plan and deterministic-lock guarantees as
   reallocation.
6. Preserve independent progress for unrelated cards where PostgreSQL safety permits.

Acceptance:

- same-card combine/reallocate races serialize and the loser safely replans or rejects
- rows inserted or changed between preview and apply cannot produce a partial result
- malformed dates, missing roots, and stale state return actionable failures
- unrelated card/context graphs remain untouched

Commit: `fix: serialize user card reference merges`

### Slice 9: Reconcile Invoice and Exchange Graph Edges

1. Exercise existing and missing destination references/invoices, empty calendar gaps,
   year boundaries, one-installment purchases, and several transactions in one bucket.
2. Verify invoice reconstruction from final membership, including amount, comment,
   cash installment, date, paid state, and counters.
3. Verify every matching monetary card-bound exchange follows its own shifted bucket
   and every generated return projection remains canonical.
4. Inject failures during tail creation, invoice reconstruction, projection
   synchronization, integrity verification, and balance recalculation.
5. Fix only contract violations demonstrated by these examples; retain existing
   combine behavior and established exchange/message rules.

Acceptance:

- every affected row moves exactly once and every unrelated row remains unchanged
- all generated totals and associations reconcile after either mode
- every injected failure restores the complete pre-merge state

Commit: `fix: reconcile reference merge financial graphs`

### Slice 10: Complete Guarded Rollback Coverage

1. Snapshot a real complete graph before each mode, apply the merge, preview rollback,
   compensate, and compare the restored graph.
2. Cover a created tail, reused destination graph, gaps, card-bound exchanges, generated
   return projections, and destroyed source rows.
3. Add stale conflicts for moved installments, destination/tail invoices, references,
   exchanges, projections, and missing dependencies.
4. Verify rollback failures are atomic and a second valid token application remains
   idempotent through the established KAKASHI-08 contract.
5. Extend adapters only for demonstrated known graph shapes; unknown shapes remain
   read-only.

Acceptance:

- both modes are immediately previewable after a fresh successful merge
- compensation restores exact financial IDs, attributes, routing, and membership
- post-merge divergence blocks the whole rollback rather than restoring a prefix

Commit: `spec: complete reference merge rollback coverage`

### Slice 11: Finish UI, Manual Acceptance, and Closure

1. Verify localized mode labels, consequence text, retained invalid selection, precise
   failure feedback, forward-only availability, and server-side enforcement.
2. Check the merge form in light/dark and compact layouts without changing its financial
   semantics.
3. Write a repeatable manual test for combine, reallocation, year-boundary movement,
   exchanges/projections, audit preview, compensation, and conflict rejection.
4. Run focused service/request/audit/concurrency suites, JavaScript coverage, RuboCop,
   and `bin/ci`.
5. Update the sprint status and write a closure report with automated and manual
   evidence.

Acceptance:

- the operator can predict the consequence of either choice before submitting
- success and rejection remain navigable through HTML and Turbo
- automated and manual evidence satisfy the completion gate

Commit: `docs: close kakashi 21`
