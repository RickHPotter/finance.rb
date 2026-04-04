# JIRAIYA-04: Reference Edge Rewrite Runner

## Goal

The first apply slice for `reference_transactable` normalization should rewrite
existing `CashTransaction` edges to the canonical immediate-parent chain without
relying on runtime guesses.

This runner is intentionally narrower than the full normalization roadmap:

- it only rewrites existing `CashTransaction.reference_transactable` edges
- it uses `Logic::ExchangeTrioAudit` as the source of truth for expected edges
- it does not create missing transactions
- it does not rewrite message headers in the same pass

## Safety Rules

This runner should only apply rows where the canonical target is explicit in the
audit output.

Rows are considered unsupported when:

- the trio audit reports `multiple_middle_candidates`
- the trio audit reports `missing_middle`
- a proposed change targets a non-`CashTransaction` node
- a proposed change points to an unsupported reference type

This means the first runner is an operator-safe backfill tool, not a universal
repair command.

## Input Contract

The runner consumes rows from `Logic::ExchangeChainReferenceAudit`, which is a
filtered/safety-gated view over `Logic::ExchangeTrioAudit`.

Each supported candidate includes:

- source transaction id
- message id / conversation id for traceability
- chain kind / end kind / intent
- issues
- concrete `proposed_changes`

Each proposed change is an edge rewrite:

- `set_reference`
- `clear_reference`

## Apply Rules

For each supported row:

1. resolve every target `CashTransaction`
2. verify the current edge still matches the audit snapshot
3. resolve the desired parent reference
4. update all edges for that row in one DB transaction

If any planned edge in the row is no longer resolvable, the row is skipped as
stale instead of partially applied.

## Expected Use

The public rake entry points for this rollout utility were removed after the
production cleanup was completed.

The intended operator flow is now:

1. review the admin Exchange Audit UI
2. select any required middle/receiver overrides there
3. apply only the supported, reviewed rows from the screen

The underlying services still exist because the Exchange Audit screen depends on
them, but they are no longer exposed as standalone maintenance commands.

## Follow-up Work

This first runner does not solve the full problem yet.

Next slices still need to cover:

- ambiguous families with multiple sender `EXCHANGE RETURN` candidates
- creation of missing receiver-side nodes when the chain is incomplete
- message/header rewrites where the audit intent or replay payload is outdated
- migration of runtime write-paths so new rows are canonical on insert/update
