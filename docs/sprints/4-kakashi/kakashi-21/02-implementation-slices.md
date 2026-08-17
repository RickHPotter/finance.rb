# KAKASHI-21 Implementation Slices

## Overview

KAKASHI-21 adds a required merge-mode decision to the existing reference merge and
implements a forward, sequence-preserving installment reallocation. Each slice keeps
the legacy combine result stable while moving the write path toward one planned,
audited, rollbackable operation.

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
   month/year, reference date, and invoice association only.
5. Rebuild every affected invoice from final membership.
6. Remove empty source/intermediate invoices and finally destroy the source reference.
7. Preserve the existing target-closing-boundary merge behavior.
8. Recalculate balances once from the earliest affected billing date after integrity
   checks pass.

Acceptance:

- the 12-installment January–December example ends in January 2027
- installment IDs, parent transaction IDs, numbers, counts, and monetary values do not
  change
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
