# JIRAIYA-06 Slice 6: Isolation And Operational Hardening

## Goal

Prove that contexts are truly isolated in practice and close the remaining silent
corruption paths before production-style validation.

## Delivered

### Cross-context Isolation Coverage

- request-level CRUD isolation for:
  - `CashTransaction`
  - `CardTransaction`
  - `Budget`
  - `Investment`
  - `Subscription`
  - `Reference`
- request coverage for wrong-context access denial
- message replay/apply coverage in derived scenarios

### Side-effect Coverage

- `Logic::RecalculateBalancesService`
- budget remaining-value recalculation
- bulk cash-installment actions
- `CARD ADVANCE`
- reference merge/edit side effects
- subscription cascade updates

### Operational Hardening

- import flows explicitly scoped to `main_context`
- exchange backfill tooling explicitly scoped to `main_context`
- due-payments notifier explicitly scoped to `main_context`
- naming-convention batch scoped to `current_context`
- `UserCard` financial helpers no longer fall back to user-global financial data
- assistant pending/actionable resolution uses the active context

### Runtime Safety And Benchmarking

- benchmark task for `Logic::RecalculateBalancesService`
- additional indexes for context-era installment join paths
- homolog/staging checklist support for context-aware scenario validation
- archived derived context removal no longer relies on callback-heavy
  `destroy!` cascades
- archived derived context removal now uses `Logic::ContextPurgeService`
  with ordered `delete_all` purge semantics
- purge runs inside one database transaction and rolls back on invariant failure
- purge acquires a user-scoped advisory lock to avoid concurrent drift during
  before/after validation
- purge performs a cross-context dependency audit before deleting archived data
- purge snapshots the main context before and after purge and aborts if counts
  or balance ledgers drift
- purge enforces ownership inside the service, not only at controller lookup
- purge deletion scopes for polymorphic rows are type-specific, preventing
  same-id collisions across `CashTransaction`, `CardTransaction`, `Investment`,
  and `Subscription`
- request and service specs now cover:
  - archived leaf derived context removal
  - cross-context dependency blocking
  - rollback on invariant failure
  - ownership enforcement
  - polymorphic id-collision safety

## Result

At the end of this slice, the main remaining gaps are no longer silent
cross-context mutation paths. The feature is implementation-complete and ready for
homolog validation, with rollout still gated by manual validation and operational
confidence.

## Boundary

This slice does not finish scenario archive/destroy behavior and does not replace
manual homolog verification with browser-level system coverage.

## Post-incident Note

During production-style validation, archived derived context removal exposed a real
polymorphic deletion bug: mixed `transactable_id` pools could delete main-context
`category_transactions` / `entity_transactions` when ids collided across
transactable types. The shipped purge service and its regression coverage exist
specifically to close that corruption path before further rollout.

## Handoff Snapshot - 2026-05-07

This slice is no longer only "context isolation". It now also carries the
operational lessons from the production incident and the follow-up hardening that
was required to make context removal trustworthy.

### What Actually Happened

- archived derived context removal originally used a callback-heavy destroy path
- that path was too slow for production-sized contexts and was replaced with
  `Logic::ContextPurgeService`
- the first purge implementation had a real bug in polymorphic deletion scoping:
  mixed `transactable_id` pools could delete main-context
  `category_transactions` / `entity_transactions` when ids collided across
  different transactable types
- production, homolog, and local were restored from backup after this was found

### What The Current Purge Path Guarantees

- purge is ordered `delete_all`, not recursive `destroy!`
- purge is wrapped in one transaction
- purge acquires a user-scoped advisory lock
- purge performs a preflight cross-context dependency audit
- purge snapshots the main context before and after:
  - counts for context-owned financial records
  - `CashInstallment.balance` and `Budget.balance` ledgers ordered by `order_id`
- purge recalculates main-context balances before both snapshots
- purge aborts and rolls back on invariant drift
- purge enforces ownership at the service layer, not only in the controller
- polymorphic rows are now deleted by type-specific scopes

### Coverage That Exists Now

- [spec/services/logic/context_purge_service_spec.rb](/home/gyndev-d06/personal/Ruby/finance.rb/spec/services/logic/context_purge_service_spec.rb)
  covers:
  - ownership enforcement
  - cross-context dependency blocking
  - invariant rollback
  - polymorphic id-collision safety
- [spec/requests/contexts_spec.rb](/home/gyndev-d06/personal/Ruby/finance.rb/spec/requests/contexts_spec.rb)
  covers the controller path and user-facing failure modes

### Related Shipped Hardening

- `Entity` now has a built-in self entity concept:
  - `built_in: true`
  - the default built-in entity is created as `MOI`
  - it can be renamed
  - it cannot be destroyed or deactivated
- code paths that previously treated literal `"MOI"` as special have been moved
  toward `built_in?` semantics where they were found in active flows

### Reminder Operations Snapshot

Reminder reliability work ended up belonging to this slice as well because the
notifier had to become explicitly context-safe and operationally predictable.

What is true now:

- due-payment reminder selection is scoped to `user.main_context`
- derived-context installments are intentionally ignored
- reminder buckets are:
  - overdue
  - due today
  - due tomorrow
- email digest is now the reliable fallback channel when mobile PWA push delivery
  is inconsistent, especially on iPhone
- push behavior is intentionally narrower than email behavior:
  - one high-urgency overdue summary notification
  - one push per due-today installment
  - no push for tomorrow-only reminders
- email digest currently sends only when there is at least one overdue or due-today
  installment
- reminder delivery iterates all users, with each user's reminder selection limited
  to that user's `main_context`

Coverage that exists now:

- [spec/services/due_payments_notifier_spec.rb](/home/gyndev-d06/personal/Ruby/finance.rb/spec/services/due_payments_notifier_spec.rb)
  covers:
  - main-context-only reminder selection
  - email digest contents across overdue / today / tomorrow
  - multi-user reminder delivery
  - single overdue-summary push behavior

### What Is Stable Enough To Assume Next Session

- derived-context purge is usable again
- production restore/recovery steps were validated in practice
- the known corruption path from polymorphic purge deletion is closed
- any further work in this area should be additive hardening or observability, not
  another redesign of the purge mechanism
