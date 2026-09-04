# KAKASHI-18 V2 Implementation Slices

## Delivery Rule

Each slice leaves its touched boundary safer and covered. The index merge actions
are restored only after the backend and rollback gates are satisfied, so an
intermediate branch state never exposes a known-unsafe merge workflow.

## Slice V2-1 — Characterize the Gap and Correct Navigation Ownership

- Add regression coverage proving Category/Entity indexes are the intended merge
  entry surfaces and show pages are not.
- Remove the broken Category/Entity show-page merge actions.
- Add pending backend contract examples for context isolation, exact stale
  detection, accepted modes, and guarded rollback, then make subsequent slices
  satisfy them without weakening the assertions.
- Keep the index triggers temporarily absent until the execution path is safe.

Commit: `spec: define kakashi 18 v2 completion boundary`

## Slice V2-2 — Bind Plans to Context and Exact Rows

- Require `context` in Category and Entity planners.
- Inventory every source allocation and fail closed on cross-context, unowned,
  missing, or unsupported owners.
- Represent Category effects as exact row plans rather than aggregate counts.
- Include context, mode, row identities, conflict facts, and relevant master
  state in deterministic plan digests and preview tokens.
- Reject missing or unknown modes explicitly.

Commit: `fix: bind merge previews to exact context graphs`

## Slice V2-3 — Complete Category Merge Policy and Locking

- Classify each allocation through existing Category allocation policy.
- Add structural-family, Subscription-owned, Budget-final-state, and destination
  conflict coverage.
- Lock source, destination, and planned joins deterministically before replan.
- Apply transfer/collapse operations atomically and validate the final graph.
- Recompute affected Budget matching, description, counters, and destination
  totals.

Commit: `fix: enforce safe category merge policy`

## Slice V2-4 — Complete Entity Merge Policy and Locking

- Reuse structural-family and neutrality policies for every Entity allocation.
- Validate both source and destination rows before duplicate collapse.
- Implement explicit Subscription, Piggy Bank, exchange, generated-family,
  same-owner, and canonical friend-identity conflicts.
- Prove complete-graph independence before offering eligible-only mode.
- Lock, replan, apply, validate, and refresh derived data atomically.

Commit: `fix: enforce safe entity merge policy`

## Slice V2-5 — Audit and Roll Back Master Merges

- Capture Category and Entity master lifecycle changes with resolvable owner
  metadata.
- Register dedicated guarded-rollback adapters and dependency ordering.
- Ensure source recreation precedes restoration of joins that reference it.
- Restore collapsed and reassigned allocations plus Budget and counter-derived
  state.
- Add strict Category, strict Entity, eligible-only Entity, stale rollback, and
  compensation-failure atomicity specs.

Commit: `feat: rollback category and entity merges`

## Slice V2-6 — Complete Selector Alias Ranking

- Give aliases exact, starts-with, word-start, and substring classification while
  preserving primary-label precedence.
- Supply and document stable User Bank Account and User Card alias tokens from
  data the models actually expose.
- Add executable JavaScript coverage for the complete normalization/ranking
  matrix and keyboard-visible order.

Commit: `fix: complete combobox alias ranking`

## Slice V2-7 — Restore the Index Workflow

- Restore Category and Entity index row triggers and per-row Turbo preview
  frames on desktop and mobile.
- Exercise destination selection, re-preview, conflict feedback, strict apply,
  eligible-only apply, cancellation, success redirect, and canonical URL state.
- Keep protected sources hidden and validate forged requests server-side.
- Verify dark/light and mobile/desktop presentation without adding show-page
  actions.

Commit: `feat: restore safe category and entity merge workflows`

## Slice V2-8 — Final Verification and Closure

- Run focused planner, apply, preview, request, navigation, concurrency, audit,
  and JavaScript checks.
- Run `bin/ci`.
- Update KAKASHI-18 status and record any deliberately rejected future scope.

Commit: `docs: close kakashi 18 v2`

