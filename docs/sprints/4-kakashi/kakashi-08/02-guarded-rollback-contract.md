# KAKASHI-08 Guarded Rollback Contract

## Objective

Rollback is a new audited compensating operation. It does not delete versions, mutate
history, bypass validations, or restore one convenient row while ignoring the rest of
the operation graph.

The first release is admin-only and operation-wide.

## Terminology

- **Original operation:** the committed operation selected for compensation.
- **Before state:** each record's state immediately before the original operation.
- **Expected after state:** each record's state immediately after the original operation.
- **Current state:** live database state at preview or apply time.
- **Compensation:** validated create, update, or destroy work that returns the graph to
  the before state while producing new versions.
- **Conflict:** any relevant current state that no longer equals the expected after state.

## Supported Boundary

- Select one `AuditOperation`, optionally from one of its versions.
- Include every version in that operation across owners, contexts, projections, and
  shared records.
- Collapse multiple versions of the same record within the operation into one net
  before/after transition.
- Do not permit individual-record rollback when the operation contains other versions.
- Do not automatically traverse into later operations. Later dependent changes are
  detected as conflicts and block the rollback.
- Rollback of a previous rollback is out of scope for the first release.

## Reconstructing Net State

For each `(item_type, item_id)` pair:

- the earliest version supplies the state before the operation
- ordered `object_changes` produce the expected final state
- a create event has no before state and must be compensated by destruction
- an update event has before and expected after states and must be compensated by update
- a destroy event has a before state and no expected live state and must be compensated
  by recreation with its historical ID
- create followed by destroy inside the same operation has no net live effect and
  requires no compensation, but remains visible in the preview

Do not use PaperTrail association reification as a graph rollback engine. Build one
explicit adapter per audited model family so ownership, validations, dependency order,
and recalculation requirements remain reviewable.

## Dry-Run Preview

Every apply request is preceded by a server-generated preview containing:

- original operation metadata and actor
- affected owners and contexts
- record type and ID
- original event sequence
- proposed compensating action
- human-readable before, expected-after, and current values
- conflicts and prohibited actions
- paid-history confirmation requirements
- projected balance/reference/projection recalculations
- records that require recreation or destruction
- a deterministic preview digest

Preview is read-only. It creates no business versions. Rejected preview/apply attempts
are recorded as immutable rollback operations with a bounded reason code and no
sensitive parameter dump.

## Conflict Detection

Rollback is allowed only when every relevant current record matches the expected after
state of the original operation:

- expected live record missing: conflict
- expected destroyed record present: conflict
- audited attribute differs: conflict
- ownership or context differs: conflict
- a dependent record created by a later operation would be orphaned: conflict
- a routing/reference relationship no longer matches: conflict
- paid history changed after the original operation: conflict

Ignore cache-only counters, totals, balance, and timestamps during equality checks.
They are recalculated after compensation. Never ignore canonical financial values.

There is no force checkbox in V1. "Resolve explicitly" means correct or roll back the
newer conflicting operation first, then request a fresh preview.

## Apply Protocol

1. Authorize the current user as an admin.
2. Load the original operation and all versions without owner scoping.
3. Acquire database locks for live affected records in deterministic type/ID order.
4. Rebuild the preview from locked current state.
5. Compare the submitted preview digest with the new digest.
6. Reject when the digest changed or any conflict/prohibition remains.
7. Create a new `AuditOperation` with source `rollback` and
   `rollback_of_operation_id`.
8. Apply compensation in dependency-aware order inside one database transaction.
9. Run normal validations, callbacks, ownership/context checks, and safety guards.
10. Run canonical recalculation and synchronization from the earliest affected date.
11. Validate the resulting graph and commit the compensation and its new versions
    together.

An exception or failed validation rolls the entire compensation back. After rollback,
write one immutable failed rollback operation with a stable reason code; do not retain
partial business versions.

## Dependency Order

Maintain an explicit registry rather than deriving order from table names.

Recreation order begins with routing/parent records and then dependents:

1. user cards, bank accounts, and references when included
2. cash/card transactions, budgets, subscriptions, and investments
3. installments and category/entity allocations
4. entity exchanges and Piggy Bank links/projections

Destruction compensation runs the reverse order. Updates are grouped by family and may
require a two-phase assignment when foreign keys point between records recreated by
the same operation.

The final implementation must refine this registry against actual foreign keys and
model callbacks before enabling each adapter.

## Paid-History Rules

- Existing paid-history validations remain authoritative.
- A preview identifies every paid or historically locked record.
- Apply requires the existing explicit historical-correction confirmation whenever a
  normal edit would require it.
- A prohibited paid-history reversal remains prohibited even for an admin rollback.
- Generated card payments, advances, exchange returns, shared returns, and Piggy Bank
  returns are restored only through their source graph adapter, not as isolated rows.

## Recalculation Contract

Collect affected owner/context pairs and the earliest changed financial datetime.
After compensation and before commit:

- rebuild or synchronize generated projections through their canonical services
- recalculate installment ordering and balances from the earliest changed date
- recalculate user-card and bank-account totals/counters
- reconcile reference routing for affected card cycles
- recalculate subscription, budget, investment, exchange, and Piggy Bank derived state
  only through their existing canonical entry points
- run targeted integrity checks for every affected graph family

Derived cache values are not reified from versions.

## Rollback Adapters

Each adapter declares:

- supported record types and event combinations
- audited attributes and ignored derived fields
- ownership/context resolver
- current-state comparison
- dependency edges
- preview representation
- compensation implementation
- paid-history policy
- post-compensation recalculations
- integrity verifier

An operation is rollbackable only when every version belongs to a supported adapter.
Unsupported versions remain readable and make the operation explicitly read-only.

Recommended rollout order:

1. ordinary cash transactions and cash installments
2. ordinary card transactions and card installments
3. category/entity allocations
4. budgets, subscriptions, and investments
5. references, user cards, and bank accounts
6. exchange/shared-return graphs
7. Piggy Bank graphs

## Authorization

- Only admins can preview or apply rollback across any user.
- Non-admin users can inspect their own versions but receive no rollback routes or
  controls.
- Admin history queries are global; rollback still verifies that every version belongs
  to a recognized owner and context before compensation.
- Actor identity is captured on every preview rejection and applied compensation.

## Idempotency and Concurrency

- Apply requires the preview digest and original operation ID.
- Use an idempotency key unique to the admin, original operation, and preview digest.
- Repeated apply requests return the previously-created rollback result rather than
  applying compensation twice.
- Lock the original operation's rollback application key during apply.
- A newer mutation between preview and apply changes the digest and returns a conflict.

## Result States

- `previewable`: no current conflict; apply may still require confirmation
- `read_only`: at least one version has no rollback adapter
- `conflicted`: current state diverged
- `prohibited`: a financial safety rule forbids compensation
- `applied`: compensation committed
- `rejected`: authorization, stale digest, or validation rejected the request
- `failed`: unexpected error rolled the compensation back

Every result is localized for the UI and has a stable machine reason code for tests and
future health-check integration.

## Explicit Non-Goals

- database time travel
- arbitrary version editing
- force-applying through conflicts
- disabling callbacks or validations to make reification save
- automatic rollback triggered by integrity audits or health checks
- partial compensation of one record from a multi-record operation
- user-initiated rollback in V1
- rollback of rollback in V1
