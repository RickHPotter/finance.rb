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
