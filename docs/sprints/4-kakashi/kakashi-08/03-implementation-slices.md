# KAKASHI-08 Implementation Slices

## Delivery Strategy

Build trustworthy history before exposing compensation. Audit storage, operation
context, model coverage, read authorization, preview, and rollback application are
separate gates. A model family may appear in history before it becomes rollbackable;
the UI must label that state explicitly.

Do not enable broad `has_paper_trail` coverage in one commit. Each model family must
pass ownership, direct-SQL, destruction, payload, and callback-recursion checks first.

## Slice 1: Prove the PaperTrail foundation

1. Add PaperTrail 17 and lock its supported version range.
2. Generate a custom version class and replace generated text/YAML payload columns with
   PostgreSQL `jsonb`.
3. Add `audit_operations` and `audit_versions` with the columns, constraints, and
   indexes from the data contract.
4. Configure version failures to raise, unlimited retention, and explicit
   create/update/destroy events without touch-only noise.
5. Add Active Record and PostgreSQL append-only guards.
6. Verify STI reification for cash/card installments under Ruby 4 and Rails 8.1.
7. Benchmark representative version insert and query costs before enabling models.

Primary touchpoints:

- `Gemfile` and `Gemfile.lock`
- `db/migrate/*create_audit_operations.rb`
- `db/migrate/*create_audit_versions.rb`
- `app/models/audit_operation.rb`
- `app/models/audit_version.rb`
- `config/initializers/paper_trail.rb`
- focused audit model specs

Acceptance criteria:

- JSONB object and changeset round trips preserve integers, booleans, nulls, dates, and
  STI subtype
- audit rows cannot be updated or destroyed through Active Record or SQL
- audit failure aborts the surrounding business transaction
- no version limit or retention deletion is configured
- existing records receive no synthetic versions

Commit: `feat: establish immutable financial audit storage`

## Slice 2: Introduce operation and ownership context

1. Add request-safe `Audit::Current` and `Audit::Operation` boundaries.
2. Wrap mutating controller actions with actor, selected context, request ID, and `web`
   source metadata.
3. Add explicit source wrappers for imports, admin repairs, actionable messages,
   shared synchronization, projections, references, Piggy Banks, and recalculation.
4. Add job propagation using a new operation ID and causal parent operation ID.
5. Implement the per-model ownership/context resolver registry.
6. Lazily create an operation on the first version and reset all state after every
   request, job, and spec.
7. Fail closed when a financial version has no owner.

Primary touchpoints:

- `app/models/audit/current.rb`
- `app/services/audit/operation.rb`
- `app/services/audit/ownership_resolver.rb`
- `app/controllers/application_controller.rb`
- `app/jobs/application_job.rb`
- import, message, projection, and repair service boundaries
- operation/request/job specs

Acceptance criteria:

- one HTTP mutation and its synchronous callbacks share one operation ID
- nested work may change mutation source without losing root source
- a later job receives a new operation ID linked to its parent
- thread/request/job state never leaks into the next example or request
- no-op and failed validation requests create no operation/version

Commit: `feat: capture financial audit operation context`

## Slice 3: Audit core transaction graphs

1. Enable versions for cash/card transactions and installment STI.
2. Enable category/entity allocations and exchanges.
3. Add model-specific skipped-derived-attribute lists.
4. Audit create, update, and destroy graph operations with denormalized owner/context.
5. Inventory and replace or explicitly capture callback-bypassing writes in transaction,
   installment, exchange, shared-return, card-advance, and projection code.
6. Capture pre-destruction versions for necessary bulk deletion paths.
7. Prove generated records share the operation but expose their immediate source.

Primary touchpoints:

- audited transaction and graph models
- `ExchangeCashTransactable`, `CashTransactable`, and installment concerns
- cash/card controllers and shared synchronization services
- `Audit::BulkMutation`
- model, concern, service, and request specs

Acceptance criteria:

- source and generated projection versions share one operation ID
- cash/card installment versions retain correct STI subtype
- destroy history remains queryable after every live row is gone
- paid-history rejection creates no partial versions
- no in-scope `update_columns`, `update_all`, or `delete_all` path silently bypasses
  version creation
- counter/balance recalculation does not flood history with cache-only versions

Commit: `feat: audit transaction and exchange graphs`

## Slice 4: Audit remaining financial models

1. Enable `Reference`, `UserCard`, `UserBankAccount`, `Budget`, `Subscription`,
   `Investment`, and `PiggyBank`.
2. Complete ownership resolvers for direct and inherited ownership.
3. Handle direct SQL in reference/card resynchronization, imports, Piggy Bank projection,
   context cloning/purge, budget bulk actions, and linter/admin repairs.
4. Separate canonical financial changes from derived totals and counters.
5. Add payload-size enforcement and model-specific metadata allowlists.
6. Run the complete callback-bypass inventory and document every intentional exclusion.

Acceptance criteria:

- every initial-scope model records create/update/destroy when changed after deployment
- user card/account history remains readable without a selected record context
- Piggy Bank source, contributions, return, and investments share causal operation data
- context purge retains destruction evidence for every audited financial row
- bulk import/repair operations have bounded metadata and complete before-state capture
- oversized or unowned versions fail visibly and atomically

Commit: `feat: complete persistent financial audit coverage`

## Slice 5: Add authorized history surfaces

1. Add shared operation and version query objects with pagination and indexed filters.
2. Add authenticated operation index/show routes and record history routes.
3. Scope non-admin readers by persisted `owner_id` before loading operations.
4. Allow admins to query every owner/context and inspect complete cross-user operations.
5. Add filters for record type/ID, operation, actor, owner, context, event, source,
   request ID, and date range.
6. Render translated before/after changes and a secondary raw JSON disclosure.
7. Link supported show pages to their record timelines and keep destroyed records
   discoverable centrally.

Primary touchpoints:

- audit routes and controllers
- `Audit::OperationQuery` and `Audit::VersionQuery`
- Phlex operation list/detail/timeline views
- locale files
- request and authorization specs

Acceptance criteria:

- admin sees global operations and full cross-user detail
- ordinary users see only versions where they are the stored owner
- a mixed-owner operation is partially represented to an ordinary user without leaking
  hidden record values or existence details
- destroyed records render from immutable version data
- all filters paginate deterministically and use indexed columns
- raw JSON never bypasses the same authorization scope

Commit: `feat: expose authorized financial history`

## Slice 6: Build rollback preview and conflict detection

1. Add the rollback adapter registry and net-state reconstruction.
2. Implement current-state comparison excluding only declared derived fields.
3. Add dependency and unsupported-adapter reporting.
4. Add paid-history and ownership/context safety evaluation.
5. Produce deterministic preview rows and a signed/digested apply token.
6. Add admin-only preview routes and rejected-attempt operation records.
7. Begin with ordinary cash/card transaction and installment adapters.

Acceptance criteria:

- preview changes no business record and creates no financial versions
- repeated previews over unchanged data produce the same digest
- later changes invalidate the digest and identify conflicts
- unsupported graph families make the whole operation read-only
- non-admin users cannot discover preview endpoints or controls
- paid-history requirements are explicit before apply

Commit: `feat: preview guarded financial rollback`

## Slice 7: Apply atomic compensation

1. Lock affected rows and rebuild the preview inside the apply transaction.
2. Add idempotency for repeated apply requests.
3. Apply create/update/destroy compensation in dependency-aware order.
4. Record the rollback as a new operation linked to the original operation/version.
5. Run canonical recalculation and integrity verification before commit.
6. Record rejected and failed attempts without retaining partial financial versions.
7. Expand adapters in the documented rollout order only after each graph family passes
   success, conflict, paid-history, and recalculation coverage.

Acceptance criteria:

- successful compensation creates a new immutable operation and new versions
- original history remains unchanged
- one failing record rolls back every compensation and recalculation
- repeated apply requests do not compensate twice
- current-state races return conflict instead of overwriting later work
- balances, references, counters, and generated projections match canonical services
  after commit

Commit: `feat: apply guarded financial rollback operations`

## Slice 8: Hardening and rollout

1. Run complete models, concerns, services, requests, jobs, and feature coverage.
2. Add recursion, concurrent request, job-state leakage, and payload-limit tests.
3. Measure audit table growth and representative operation/history query plans.
4. Verify PostgreSQL append-only triggers in production-like configuration.
5. Verify light/dark, desktop/mobile, pagination, raw disclosure, destroyed records,
   global admin access, and owner-only user access.
6. Document deployment order, migration duration, rollback of the application release,
   and monitoring without deleting audit data.
7. Keep rollback adapters disabled behind a per-family registry until their full graph
   coverage passes.

Operational runbook: [deployment and operations](06-deployment-and-operations.md).

Acceptance criteria:

- no audit context leaks between requests/jobs
- no callback recursion or duplicate version for one model event
- query plans use the expected metadata indexes
- broad suite runtime remains measured and acceptable
- disabling the UI does not disable audit capture
- application rollback leaves already-written immutable audit history readable

Commit: `spec: harden financial audit and rollback behavior`

## Merge Gate

Before merge:

- run `bin/rubocop -A`
- run audit model/service/request/job specs with versioning enabled
- run `spec/models`, `spec/concerns`, and `spec/requests`
- run affected services and jobs outside the current CI directory set
- run `bin/ci`
- inspect migration SQL, indexes, trigger behavior, and representative `EXPLAIN` output
- manually verify both admin-global and owner-only history access
- manually preview and apply one supported rollback and reject one conflicted rollback
