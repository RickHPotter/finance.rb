# JIRAIYA-04: `reference_transactable` Runtime Migration Slices

## Slice 1: Contract and audit visibility

- document the canonical parent-chain contract
- expose current reference edge vs expected reference edge in the admin exchange audit
- classify rows as pending when any node is missing or points to the wrong parent

## Slice 2: Chain navigation helpers

- add helpers to resolve parent, root, and descendants for shared exchange flows
- move message local-target lookup toward chain traversal
- keep legacy links readable during this transition

## Slice 3: Message resolution migration

- update actionable create/update lookup to resolve chain descendants safely
- update destroy resolution to stop depending on a direct reverse reference
- update paid-state sync lookup to use chain-aware resolution

## Slice 4: Canonical writes

- change create/update flows so new records write the canonical immediate-parent edge
- remove temporary controller/form normalization that only exists to paper over mixed
  reference semantics

## Slice 5: Backfill and cleanup

- run audit/apply against existing production-shaped data
- verify the settings screen before and after apply
- remove fallback paths that only support legacy direct-to-source links

## Final Outcome

All five slices were completed in the shipped rollout.

Final state:

- new shared-return writes follow the canonical immediate-parent chain
- actionable create/update/destroy resolution is chain-aware
- shared paid-state sync is chain-aware
- historical production-shaped data was normalized during rollout
- legacy fallback paths and rollout-only repair tooling were removed afterward
- the admin Exchange Audit screen remains as the permanent operator surface
