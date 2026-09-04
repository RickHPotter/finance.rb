# KAKASHI-18 V2 Completion Contract

## Status

KAKASHI-18 V1 established selector ranking and a Category/Entity merge service
layer, but it did not satisfy the complete product, isolation, concurrency, or
rollback contract. The working index entry points were later removed by mistake,
while replacement actions were added to the show pages outside the locked V1
navigation decision.

V2 is a corrective completion boundary. The original product contract remains
authoritative except where this document makes an ambiguity explicit. V2 must not
be described as complete merely because the planner and apply happy paths pass.

## Existing Work Retained

V2 keeps and hardens the following V1 foundations:

- normalized client-side combobox searching;
- primary-label ranking tiers;
- separate preview and apply controllers;
- short-lived signed preview tokens;
- strict Category merge mode;
- strict and eligible-only Entity merge modes;
- allocation-row audit capture through `Audit::BulkMutation`;
- localized preview pages and conflict feedback.

## User Interface Contract

The merge entry point belongs on each eligible Category or Entity row in the
index. It opens the preview workflow in an in-place Turbo frame and leaves the
canonical index URL unchanged. Desktop and mobile indexes must provide the same
capability.

The Category and Entity show pages must not expose merge actions. Those actions
were added after V1 and do not work as the intended modal workflow. Their removal
is a correction, not a product-scope reduction.

The index trigger is hidden for protected source records. Destination options
exclude the source, inactive records, and records that can never be valid
destinations. Server policy remains authoritative for forged requests.

## Context and Ownership Boundary

Categories and Entities are user-owned master records, while their allocations
belong to context-owned financial records. V2 retains the original rule that a
single merge may not cross contexts.

The planner therefore receives `actor` and `context` and inventories every live
allocation referring to the source. It fails closed when any allocation:

- belongs to another user;
- belongs to a context other than the selected context;
- has a missing or unsupported owner;
- cannot be proven to belong to the selected context.

V2 never silently ignores an out-of-context allocation, because destroying the
source master record would delete or orphan that allocation. The preview reports
the blocking count without exposing another context's financial details.

## Exact Preview and Stale-State Contract

A preview token binds all of the following:

- actor ID;
- selected context ID;
- source and destination IDs;
- merge mode;
- exact transfer, collapse, and conflict row identities;
- conflict reason and structural-family facts that affect eligibility;
- the source and destination state relevant to merge eligibility.

Aggregate counts alone are not an adequate fingerprint. Replacing one row with
another while preserving the same counts must make the preview stale.

Apply verifies the token, locks the source, destination, and complete affected
row set in deterministic order, replans under lock, and compares the exact digest
before performing a write. Missing, additional, or changed rows reject the apply
without mutation.

Only `strict` and `eligible_only` are accepted Entity modes. Category accepts only
`strict`. A missing or unknown mode fails closed rather than falling through to
eligible-only behavior.

## Category Merge Safety

Each source allocation is evaluated through the established allocation policy
instead of being treated as an ordinary foreign-key update. The planner reports
and blocks:

- built-in source or destination records;
- inactive or unowned records;
- structural category-family changes;
- Subscription-owned category allocations;
- invalid Budget final states;
- cross-context or unsupported owners.

Category merge remains all-or-nothing. Apply remaps eligible joins, collapses
exact duplicates, verifies final uniqueness and allocation invariants, destroys
the source, refreshes counters, and recomputes every affected Budget display and
matching result inside one transaction.

## Entity Merge Safety

Entity allocation classification reuses the established structural-family and
neutrality policies. The planner reports payer, monetary, exchange, Piggy Bank,
Subscription, generated-family, same-owner duplicate, friend-identity,
cross-context, and unsupported-owner conflicts explicitly.

A duplicate source allocation may be collapsed only when the destination
allocation is also neutral and the resulting owner remains valid. A destination
allocation with financial or structural meaning is not permission to discard the
source allocation.

Eligible-only mode is available only when every eligible row is independent of
every conflict row at the complete owner/linked-graph level. It applies one fixed
eligible set atomically. The source survives whenever any allocation remains.

Friend-backed Entities may merge only when both resolve to the same canonical
friend identity. Cross-friend and friend-to-ordinary merges fail closed.

## Audit and Guarded Rollback

Moving allocation rows is not a complete merge audit. The destroyed Category or
Entity master record must also be versioned in the same root operation.

V2 adds auditable ownership and registered rollback support for Category and
Entity master records. A successful strict merge must be immediately previewable
and compensatable through KAKASHI-08 guarded rollback. Rollback restores:

- the original master record with its original ID and attributes;
- every remapped or collapsed allocation row;
- affected Budget allocation and derived state;
- source and destination counters and totals.

Eligible-only Entity operations that retain the source restore only their moved
or collapsed allocation rows and derived state. Any post-merge divergence makes
rollback conflict rather than restoring a prefix.

## Selector Ranking Completion

Primary labels retain exact, starts-with, word-start, and substring tiers.
Aliases receive the same internal match classification but remain subordinate to
primary-label matches as defined by the V1 contract. User Bank Account aliases
include bank/account discovery data; User Card aliases include available card
brand and identifying suffix data. If the data model has no separate last-four
field, V2 must document and test the actual stable identifying token rather than
claiming one exists.

Focused JavaScript tests cover normalization, stable ranking, aliases,
permanently hidden items, empty results, and keyboard traversal of the reordered
visible set.

## Completion Gate

KAKASHI-18 V2 is complete only when:

- the index workflow works on desktop and mobile and no show-page merge action
  remains;
- cross-context and unsupported allocations fail before mutation;
- tokens bind the exact previewed graph and apply replans under deterministic
  locks;
- all documented Category and Entity structural conflicts are covered;
- a real strict Category merge and strict Entity merge can be fully restored by
  guarded rollback;
- eligible-only Entity rollback restores its exact allocation subset;
- the selector ranking and alias matrix has executable JavaScript coverage;
- focused service, request, audit, concurrency, and navigation specs pass;
- `bin/ci` passes on the final tree.

