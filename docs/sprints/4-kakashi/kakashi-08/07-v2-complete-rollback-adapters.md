# KAKASHI-08 V2 Complete Rollback Adapter Coverage

## Status and PR Boundary

The KAKASHI-08 V1 PR is complete and may ship independently. KAKASHI-08 remains
unfinished as a feature until a future V2 PR completes the rollback coverage in this
document.

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
for these ten audited families:

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

## Proposed V2 Delivery Order

### Slice 1: Common transaction companions

Add `CategoryTransaction`, `EntityTransaction`, and `Budget` adapters. These families
are present in common transaction create/update/destroy operations and currently make
otherwise reconstructable operations read-only.

Acceptance:

- create, update, and destroy compensation is dependency ordered
- allocation uniqueness and ownership remain valid
- budget matches and totals are recalculated through canonical services
- a complete ordinary cash and card operation containing allocations/budget versions
  can preview and apply atomically

### Slice 2: Card-payment lifecycle and routing

Add `Reference`, `UserCard`, and `UserBankAccount` adapters, then complete card
transaction/installment support for creation, destruction, billing-cycle moves,
user-card changes, card advances, and generated cash payment projections.

Acceptance:

- routing parents are restored before dependents and destroyed after dependents
- reference dates, invoice buckets, and card-payment projections match canonical
  services after apply
- merge/resynchronization operations are either completely supported or rejected for a
  specific safety conflict rather than for a missing adapter
- paid card history remains confirmation-gated or prohibited according to the locked
  rollback contract

### Slice 3: Recurring and investment graphs

Add `Subscription` and `Investment` adapters, including their generated transaction,
installment, price synchronization, and cash projection operations.

Acceptance:

- source and generated records compensate as one operation
- recurrence/routing metadata is restored without duplicating future records
- investment totals and projections are recalculated from canonical sources
- later dependent activity produces a conflict instead of being overwritten

### Slice 4: Exchanges and cross-user graphs

Add the `Exchange` adapter and cover local exchanges, shared exchanges, generated
returns, unlink/rebuild operations, and actionable-message graphs.

Acceptance:

- each version retains its immutable owner/context authorization
- mixed-owner operations remain admin-only for rollback and atomic across both sides
- shared returns and reference projections remain canonical
- missing counterpart or later counterpart activity blocks apply with a precise reason

### Slice 5: Piggy Bank graphs

Add the `PiggyBank` adapter and cover source transactions, contributions, returns,
investments, and linked projections.

Acceptance:

- all linked records compensate in dependency order
- source/return links and investment totals are restored without orphaning projections
- later withdrawals, returns, or paid history produce explicit conflicts/prohibitions
- recalculation and integrity verification run before commit

### Slice 6: Registry and graph completion hardening

Remove family-level read-only warnings only after the corresponding adapter passes its
full matrix. Exercise real operations from the UI and canonical services, not only
synthetic version fixtures.

Acceptance:

- `Audit::Rollback::Registry.supported_types` contains all concrete audited types
- an operation composed of the documented audited families never becomes read-only
  solely because a family lacks an adapter
- documented generated graphs no longer fail only with
  `unsupported_transaction_graph`
- unknown future graph shapes still fail closed
- one failing record, callback, recalculation, or integrity check rolls back the entire
  compensating operation and its versions

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
