# KAKASHI-21 Current Implementation Inventory

## Status

Inventory recorded on 2026-09-13 before new implementation work.

KAKASHI-21 has a substantial inherited implementation. It is functionally beyond a
prototype, has production-driven corrections, and already covers the principal forward
reallocation case. It is not yet considered closed because the implementation and the
full documented safety matrix have not been reconciled as one feature delivery.

## Existing Product Surface

- `Views::References::Merge` renders an explicit required radio choice for
  `combine_into_target` and `reallocate_installments`.
- `reference_merge_controller.js` disables reallocation unless the target is the
  immediately following calendar month.
- `ReferencesController` retains the submitted mode on validation failure, renders a
  `422`, and scopes the card and references through the current user/context.
- `Logic::References.merge` accepts only stable mode identifiers. Combine supports
  either adjacent direction; reallocation is forward-only.
- Localized English and PT-BR labels, consequence text, and planner failure messages
  already exist.

## Existing Reallocation Domain

`ReferenceMerges::ReallocationPlanner` currently:

- normalizes source and target to calendar-month boundaries;
- scopes installments and monetary card-bound exchanges by selected card and context;
- builds a source-through-tail calendar bucket map, including empty gaps;
- inventories destination references/invoices and records canonical graph blockers;
- rejects invalid direction, missing roots, paid installments/invoices, duplicate
  invoices, invalid invoice ownership, and locked return projections;
- captures deterministic record keys and a digest of relevant persisted state.

`ReferenceMerges::ReallocationApply` currently:

- rejects an ineligible plan before mutation;
- locks inventoried rows, replans, and compares the digest;
- moves buckets latest-to-earliest inside one transaction and one audit operation;
- preserves each `CardInstallment#date`, identity, number, count, and economics while
  changing its month/year and card-payment invoice routing;
- creates missing destination references through the established card-payment path;
- rebuilds final invoice totals and removes emptied invoices/source reference;
- moves monetary card-bound exchanges and relies on canonical callbacks to synchronize
  generated return projections;
- verifies final routing/totals and recalculates balances once;
- returns structured applied, rejected, or failed results with diagnostic logging.

## Existing Audit and Rollback Support

- Combine and reallocate operations carry scalar merge metadata in a root
  `AuditOperation`.
- Audited bulk mutation captures callback-light installment and aggregate changes.
- The rollback compensator and cash-transaction adapter recognize the reallocation
  graph.
- Existing specs prove a fresh real reallocation is previewable, restores a canonical
  graph snapshot, restores exchanges/projections, and conflicts after a moved
  installment diverges.
- Existing combine coverage proves a neighboring reference and invoice routing graph
  can be restored.

## Production-Driven Corrections Already Retained

Later fixes are part of the baseline and must not regress:

- shifted installment dates remain their original purchase/schedule dates;
- invoice synchronization is bucket-bounded rather than repeated for every moved row;
- explicitly unpaid installments do not recreate a destination invoice as paid merely
  because its reference date is today or earlier;
- an unpaid final installment can move after earlier paid history without rewriting its
  schedule date;
- destination lookup prefers the correct unpaid shifted card-payment graph.

## Reconciliation Gaps

### Shared mutation boundary

Combine remains a monolithic Boolean path while reallocation uses a planner and
structured result. Combine is atomic and audited, but it does not yet share
reallocation's explicit stale-plan and deterministic-lock contract.

### Lock scope and phantom membership

Reallocation locks the rows found by the original plan and then compares a replanned
digest. This protects the tested same-plan race, but the feature still needs executable
coverage for independently planned same-card operations, mixed combine/reallocate
races, membership inserted between plan and apply, and unrelated-card concurrency. The
final boundary should serialize the selected card/context graph without relying on all
writers coincidentally locking the same child rows.

### Full graph matrix

The current suite covers the principal 12-installment/year-boundary case, preserved
dates, gaps, paid-history boundaries, multiple reassignments, exchange projections,
stale state, failure rollback, and one same-card race. The written matrix remains wider:
existing versus created tail graphs, several independent purchases per bucket, exact
invoice dates/paid states/counters, mixed-mode races, and every failure stage need an
explicit reconciliation pass.

### Rollback conflict matrix

Exact fresh rollback and one moved-installment conflict are covered for reallocation.
The remaining declared cases include divergence of a reference, reused or created tail
invoice, exchange, generated projection, and a missing dependency, plus atomic failure
and idempotent reapplication evidence. Combine also needs the same graph-level
snapshot standard rather than only selected restoration assertions.

### Operational and manual closure

The feature has no dedicated manual-verification guide or closure report. The final
delivery must verify both modes through the real form, generated invoice and exchange
return graphs, audit preview/revert, Turbo navigation, localized feedback, and the full
CI gate.

## Non-Regression Boundaries

- Do not infer a mode from card issuer, card name, or historical selection.
- Do not change installment number, count, amount, transaction identity, or original
  date during reallocation.
- Do not rewrite paid/locked history to force eligibility.
- Do not change existing combine results while extracting shared safety machinery.
- Do not change actionable-message send, receive, supersession, pending, or auto-apply
  rules. Any such change requires explicit product approval and separate coverage.
- Do not repair old completed merges or introduce partial/forced rollback in this
  feature.

## Development Start Point

Slice 7 is complete. Proceed with Slices 8–11 in the implementation plan. The original
Slices 1–6 are an inherited baseline to verify, not work to duplicate. Any newly
discovered mismatch is first expressed as a failing focused spec; implementation
follows in the same slice.
