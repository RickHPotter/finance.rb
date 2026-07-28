# KAKASHI-08 V2 Complete Rollback Adapter Coverage

## Status and PR Boundary

The KAKASHI-08 V1 PR is complete and may ship independently. V2 is now the active
KAKASHI-08 completion boundary and covers the ten confirmed missing public adapters
plus the internal Budget allocation companions required to restore a Budget graph.

V1 intentionally fails closed. An operation containing a record family with no
rollback adapter or an unsupported generated graph has a readable preview but no apply
action. V2 expands that safe boundary; it does not add partial rollback, conflict
override, or a force option.

## V2 Objective

Add a rollback adapter for every audited financial record family and support the
generated graphs produced by the application's canonical mutation services. A V2
adapter must reconstruct and compensate the complete operation, preserve ownership
and routing, obey paid-history rules, and run canonical recalculation and integrity
checks atomically.

The literal V1 warning `This record family has no rollback adapter` remains expected
for these ten audited families and must be removed by V2:

1. `CategoryTransaction`
2. `EntityTransaction`
3. `Exchange`
4. `Reference`
5. `UserCard`
6. `UserBankAccount`
7. `Budget`
8. `Subscription`
9. `Investment`
10. `PiggyBank`

`BudgetCategory` and `BudgetEntity` are not separate product features, but they must
join the audited and rollbackable set in V2. A Budget snapshot without its category
and entity membership is not a complete financial state.

## Complete Audited-Family Inventory

| Audited family | V1 state | V2 obligation |
| --- | --- | --- |
| `CashTransaction` | V1 registered; ordinary and price-only projection updates | complete every documented generated/special graph |
| `CardTransaction` | V1 registered; ordinary and safe price-only edits | complete create/destroy, cycle moves, routing, advances, and generated graphs |
| `CashInstallment` | registered through the installment adapter | complete generated lifecycle, routing, and dependent-graph coverage |
| `CardInstallment` | registered through the installment adapter | complete generated lifecycle, billing-cycle, and dependent-graph coverage |
| `CategoryTransaction` | audited, no adapter | add create/update/destroy allocation compensation and dependency ordering |
| `EntityTransaction` | audited, no adapter | add create/update/destroy allocation compensation and exchange dependency ordering |
| `Exchange` | audited, no adapter | add local, shared, return, unlink, and projection compensation |
| `Reference` | audited, no adapter | add merge, move, resynchronization, and generated-reference compensation |
| `UserCard` | audited, no adapter | add routing, billing-reference, merge/resync, and destruction safety |
| `UserBankAccount` | audited, no adapter | add account routing, context purge, total recalculation, and destruction safety |
| `Budget` | audited, no adapter | add budget lifecycle compensation and canonical match/recalculation |
| `BudgetCategory` | not audited separately | audit and compensate as a Budget-owned allocation companion |
| `BudgetEntity` | not audited separately | audit and compensate as a Budget-owned allocation companion |
| `Subscription` | audited, no adapter | add subscription lifecycle and generated transaction graph compensation |
| `Investment` | audited, no adapter | add investment lifecycle and generated cash/Piggy Bank projection compensation |
| `PiggyBank` | audited, no adapter | add source, contribution, return, investment, and projection compensation |

`Installment` is audited as the STI base while rollback dispatch uses the concrete
`CashInstallment` and `CardInstallment` types. It does not require a separate base
registry entry.

## Registered Families That Remain Partial

Removing the ten missing-family warnings is necessary but not sufficient. V2 must also
close the generated-graph gaps within the four registered families:

- card transaction create and destroy with generated card installments and card-payment
  cash projections
- transaction date, billing-cycle, or user-card changes that move or reroute generated
  card payments
- card advances and their linked cash transaction graph
- subscription-generated cash/card transactions and installments
- investment-generated cash projections
- exchange, shared-return, and cross-user actionable-message graphs
- Piggy Bank source, contribution, return, and projection graphs
- reference merge/resynchronization and user-card merge/resynchronization graphs
- category/entity allocation and budget recalculation records included in otherwise
  ordinary transaction operations

The existing price-only card edit is the V1 exception: it is eligible only when the
complete existing projection graph is present, routing is unchanged, and generated
rows changed only their canonical aggregate price/comment fields.

## V2 Delivery Rules

Each slice registers a family only after its complete acceptance matrix passes. Merely
adding an adapter class is not enough. Until registration, the existing read-only
preview remains the correct behavior.

The compensator must be generalized before adding families. V1 groups everything under
cash/card transaction parents and assumes every non-parent row is an installment.
V2 must instead build a deterministic dependency plan from adapter declarations and
execute parent-before-child recreation/update and child-before-parent destruction.

Every slice ends with focused model/service/request coverage, `bin/rubocop -A`, and one
conventional commit. No slice may introduce partial apply or a force path.

## V2 Implementation Slices

### Slice 1: Generalize dependency planning and compensation

Replace the transaction-specific compensator grouping with a generic execution plan
that can handle independent roots, nested companions, and cross-family operation
graphs without weakening the V1 transaction behavior.

Acceptance:

- adapters declare stable parent/dependent edges and compensation hooks
- recreation/update order is parent before child; destruction order is child before
  parent
- cycles, missing required parents, duplicate keys, and unhandled rows fail closed
- one adapter failure rolls back all business mutations and new audit versions
- the existing cash/card/installment rollback suite remains green unchanged

Commit: `refactor: generalize audit rollback compensation`

### Slice 2: Transaction allocations

Add `CategoryTransaction` and `EntityTransaction` adapters. These families are present
in common transaction create/update/destroy operations and currently make otherwise
reconstructable operations read-only.

Acceptance:

- create, update, and destroy compensation is dependency ordered
- allocation uniqueness and ownership remain valid
- category/entity totals are recalculated through canonical services
- `EntityTransaction` waits for its parent transaction and orders `Exchange`
  dependents correctly
- ordinary cash and card operations containing allocations preview and apply atomically

Commit: `feat: rollback transaction allocations`

### Slice 3: Budget graphs

Add the `Budget` adapter and make `BudgetCategory`/`BudgetEntity` audited companion
families with their own dependency declarations.

Acceptance:

- create/update/destroy restores Budget attributes and exact category/entity membership
- nested allocation writes share the Budget operation and immutable ownership/context
- uniqueness checks run against the final planned graph rather than a half-restored
  intermediate state
- derived balance, remaining value, ordering, and monthly balances are recalculated
  canonically
- later conflicting Budget/allocation activity blocks apply

Commit: `feat: rollback complete budget graphs`

### Slice 4: References

Add the `Reference` adapter and cover ordinary lifecycle, billing-date changes,
generated references, merge/move, and resynchronization operations.

Acceptance:

- unique card/context/month/year and reference-date keys are checked before apply
- reference callbacks do not duplicate or misdate card-payment projections
- merge/move/resynchronization restores the complete included graph or fails with a
  precise conflict
- paid invoice history remains confirmation-gated or prohibited

Commit: `feat: rollback billing references`

### Slice 5: Cards, accounts, and card-payment routing

Add `UserCard` and `UserBankAccount` adapters, then complete the routing portions of
card transaction/installment compensation, including billing-cycle moves, user-card
changes, card advances, and generated cash payment projections.

Acceptance:

- routing parents are restored before dependents and destroyed after dependents
- reference dates, invoice buckets, and card-payment projections match canonical
  services after apply
- merge/resynchronization operations are either completely supported or rejected for a
  specific safety conflict rather than for a missing adapter
- paid card history remains confirmation-gated or prohibited according to the locked
  rollback contract

Commit: `feat: rollback card and account routing`

### Slice 6: Subscription graphs

Add the `Subscription` adapter and cover its allocations, generated cash/card
transactions, installments, routing metadata, and price synchronization.

Acceptance:

- source and generated records compensate as one operation
- recurrence/routing metadata is restored without duplicating future records
- derived transaction counts and subscription price are recalculated from canonical
  linked transactions
- later dependent activity produces a conflict instead of being overwritten

Commit: `feat: rollback subscription graphs`

### Slice 7: Investment graphs

Add the `Investment` adapter and cover its generated cash projection, account routing,
and Piggy Bank linkage where present.

Acceptance:

- source and generated cash projection compensate as one operation
- account and context ownership are preserved
- totals and projections are recalculated from canonical sources
- later projection, account, or Piggy Bank activity blocks stale apply

Commit: `feat: rollback investment graphs`

### Slice 8: Exchanges and cross-user graphs

Add the `Exchange` adapter and cover local exchanges, shared exchanges, generated
returns, unlink/rebuild operations, and actionable-message graphs.

Acceptance:

- each version retains its immutable owner/context authorization
- mixed-owner operations remain admin-only for rollback and atomic across both sides
- shared returns and reference projections remain canonical
- missing counterpart or later counterpart activity blocks apply with a precise reason

Commit: `feat: rollback exchange graphs`

### Slice 9: Piggy Bank graphs

Add the `PiggyBank` adapter and cover source transactions, contributions, returns,
investments, and linked projections.

Acceptance:

- all linked records compensate in dependency order
- source/return links and investment totals are restored without orphaning projections
- later withdrawals, returns, or paid history produce explicit conflicts/prohibitions
- recalculation and integrity verification run before commit

Commit: `feat: rollback piggy bank graphs`

### Slice 10: Complete transaction and installment graph support

Close the remaining V1 restrictions in `CashTransaction`, `CardTransaction`,
`CashInstallment`, and `CardInstallment` now that every companion family has a
registered adapter.

Acceptance:

- transaction create/destroy restores complete installment, allocation, exchange,
  subscription, investment, Piggy Bank, reference, advance, and payment graphs
- date/billing-cycle/user-card changes restore generated routing and projections
- paid-history rules are evaluated across the entire graph
- complete known graphs no longer emit `unsupported_transaction_graph`
- unknown future graph shapes remain read-only

Commit: `feat: complete transaction graph rollback`

### Slice 11: Registry, UI, and completion hardening

Remove family-level read-only warnings only after the corresponding adapter passes its
full matrix. Exercise real operations from the UI and canonical services, not only
synthetic version fixtures.

Acceptance:

- `Audit::Rollback::Registry.supported_types` contains all concrete audited types,
  including the two Budget companion types
- an operation composed of the documented audited families never becomes read-only
  solely because a family lacks an adapter
- documented generated graphs no longer fail only with
  `unsupported_transaction_graph`
- unknown future graph shapes still fail closed
- one failing record, callback, recalculation, or integrity check rolls back the entire
  compensating operation and its versions
- preview/apply UI copy describes graph conflicts and confirmation requirements in
  both locales
- the focused suite, affected domain suites, `yarn build`, and `bin/ci` pass

Commit: `spec: harden complete financial rollback coverage`

## Adapter Completion Checklist

Every new adapter must cover:

- net create, update, destroy, create-then-update, and create-then-destroy transitions
- exact current-state comparison with declared derived fields excluded
- ownership and context validation from immutable audit metadata
- create/update/destroy dependency declarations
- unique-key and later-dependent conflict detection
- paid-history confirmation and prohibition rules
- mutation through canonical services or explicitly justified callback handling
- derived balance, total, counter, reference, and projection recalculation
- apply-time row locking, digest revalidation, idempotency, and atomic failure
- immutable audit linkage from the compensating operation to its original operation
- request/service specs plus a real manual UI flow

## V2 Manual Acceptance Set

For each slice, retain the operation ID and verify preview, apply, history linkage, and
post-apply financial state:

1. create, update, and destroy one representative root record
2. repeat with category/entity allocations and an affected budget
3. repeat after a later edit and confirm the stale operation is conflicted
4. repeat with paid history and confirm the required confirmation or prohibition
5. repeat a successful apply request and confirm idempotency
6. force one validation/recalculation failure in test and confirm no partial records or
   versions remain
7. inspect the original and compensating operations as admin
8. inspect the original operation as its owner and confirm other-owner versions remain
   undisclosed

Graph-specific manual cases must include:

- card create/destroy with installments spanning billing months and card-payment cash
  projections
- card billing-cycle/user-card move
- card advance
- subscription create/update/destroy with generated transactions
- investment create/update/destroy with its cash projection
- reference merge/resynchronization
- shared exchange plus generated return
- Piggy Bank contribution/return flow

## V2 Completion Gate

KAKASHI-08 may be marked complete only when:

- every audited family in this document has a registered, covered adapter
- all listed generated graph cases have deterministic preview and atomic apply coverage
- unsupported future shapes remain clearly read-only
- the focused rollback suite, affected domain suites, CI scope, and `bin/ci` pass
- the manual acceptance set is recorded for the deployed revision

Audit history availability alone does not satisfy this gate. V1 remains a valid,
deployable foundation while V2 is pending.
