# KAKASHI-22 Closure Report

## Status

Implementation and automated verification are complete as of 2026-09-19. Production-shaped
manual acceptance remains explicit in [05-manual-verification.md](05-manual-verification.md);
its sign-off must not be inferred from automated test coverage.

---

## Delivered Contract

- **Authoritative Net Valuation**: The reconciliation workflow accepts an observed net
  redeemable balance from the user or bank and compares it against the recorded unpaid
  remainder (`recorded_remaining_cents`) of the generated return cash transaction.
- **Sparse Valuation Delta**: A single signed `Investment` record (using built-in investment
  type `piggy_bank`) represents the net difference between observed reality and recorded
  projections. No artificial intermediate history or daily accruals are synthesized.
- **Paid History Protection**: Settled return installments (`paid: true`) from prior partial
  withdrawals are strictly immutable. Adjustments mutate only the unpaid projected remainder.
  Fully settled groups reject reconciliation cleanly.
- **Atomic Synchronization**: Investment insertion and return projection synchronization
  (`CashTransaction#price` and remaining `CashInstallment#price`) execute in a single database
  transaction under pessimistic row locking (`FOR UPDATE`).
- **Deterministic Preview and Concurrency Safety**:
  - `PiggyBankReconciliations::Preview` is completely write-free and generates a SHA256 digest
    encapsulating target IDs, amounts, and dates.
  - `PiggyBankReconciliations::Apply` re-evaluates the graph under row locks and rejects stale
    previews (`reason_code: :stale_preview`) or raced modifications without making writes.
- **Clean Zero-Delta No-Op**: When the observed net balance matches the recorded remaining
  value exactly, the service returns `:noop`, creates no `Investment`, performs no projection
  update, and logs no empty audit operation.
- **Audit and Rollback Integration**:
  - A single root `AuditOperation` is recorded with `operation_kind: "piggy_bank_net_reconciliation"`.
  - Investment creation is marked with mutation source `web`; projection updates are marked
    with `piggy_bank_sync`.
  - `Audit::Rollback::Adapters::Investment` fully compensates the operation: removing the
    valuation `Investment`, reverting projection adjustments back to exact pre-reconciliation
    values, and aborting atomically if subsequent mutations conflict.
- **Contribution IOF Availability**:
  - Nullable `iof_exempt_on` (`date`) column added to `piggy_banks` table with index.
  - Proposes a 30-calendar-day convenience default on contribution creation without calculating
    IOF tax schedules or money.
  - Each contribution lot maintains independent availability dates and status badges
    (`waiting`, `available`, `not_recorded`).
  - Availability date changes are strictly isolated: they never move `return_date`, `return_price`,
    or cash installments.
- **Reporting & Monthly Analysis**:
  - Reconciliation valuation deltas are recognized in the observation month's profit/loss.
  - Valuation entries include clickable source navigation to the underlying `Investment` show page.
  - Original contribution amounts remain correctly positioned in the contribution month.

---

## UI and Navigation Closure

- **Reconciliation Workflow**: Dedicated interface at `/cash_transactions/:id/piggy_bank_reconciliation/new`
  with Hotwire / Turbo preview and submission.
- **Preview Card**: Dynamic `Views::PiggyBankReconciliations::PreviewCard` rendering recorded
  unpaid balance, observed net balance, and signed adjustment delta with directional indicators.
- **Return Detail & Contributions Sheet**:
  - `Views::CashTransactions::Show` augmented with a dedicated valuation and reconciliation card
    displaying return totals, prior valuation history, and contribution lot details.
  - `Views::PiggyBanks::ContributionsSheet` displays each lot's contribution date, baseline,
    availability date, and status badge.
- **Localization**: Full English (`en`) and Brazilian Portuguese (`pt-BR`) translations across
  all forms, preview summaries, status badges, flash notices, and error messages.
- **Responsive & Dark Mode**: Form controls, comparison cards, and action buttons adapt
  seamlessly to mobile widths (< 640px) without horizontal overflow and honor system/application
  dark mode styles.

---

## Automated Evidence

Focused closure verification on 2026-09-19:

- **Reconciliation Services (`spec/services/piggy_bank_reconciliations/`)**:
  - 34 examples, 0 failures: covering characterization baselines, preview calculation,
    cryptographic digest stability, apply atomicity, optimistic locking, stale rejection,
    zero-delta no-ops, audit integration, and rollback compensation.
- **Reconciliation Requests (`spec/requests/piggy_bank_reconciliations_spec.rb`)**:
  - 21 examples, 0 failures: covering route security, context isolation, HTML and Turbo
    preview/apply responses, validation failures (`422`), no-op flash notices, and redirect handling.
- **Piggy Bank Model & Feature Suites (`spec/models/piggy_bank_spec.rb`, `spec/models/cash_transaction_spec.rb`)**:
  - All 153 combined examples passing: covering IOF availability defaults, status calculation,
    paid-history projection locking, and cash transaction integration.
- **Monthly Analysis Finder (`spec/services/logic/finder/monthly_analysis_json_spec.rb`)**:
  - 14 examples, 0 failures: covering positive and downward reconciliation deltas in observation
    months, zero-delta absence, partial withdrawal preservation, and investment navigation.
- **System Health Checks & Auditing (`spec/services/health_check/checks_spec.rb`, `spec/models/financial_auditable_spec.rb`, `spec/services/logic/piggy_bank_audit_spec.rb`)**:
  - All examples passing: verifying graph integrity and audit trail compliance.

---

## Schema and Operational Notes

- **Migration**: `db/migrate/20260919130000_add_iof_exempt_on_to_piggy_banks.rb` adds nullable
  `iof_exempt_on` (`date`) column to `piggy_banks` with a standard index.
- **Zero Backfill Required**: Existing legacy rows remain valid with null `iof_exempt_on`
  values and are rendered with the "Not Recorded" (`not_recorded`) badge.
- **Non-breaking to Neighboring Domains**: Ordinary Investments, cash transactions, card
  installment splits, and exchange return projections are completely unaffected.

---

## Deferred Items

The following enhancements remain intentionally deferred to future iterations:

1. **Atomic Reconcile-and-Settle**: A combined single-step action to reconcile net valuation
   and mark the return installment settled/paid when the bank reveals only a final redemption amount.
2. **Immutable Valuation Snapshot Table**: Dedicated historical log table storing bank-reported
   snapshots independently from the linked `Investment` entity.
3. **Structured Breakdown**: Separate ledger entries for gross yield, IOF withheld, income tax (IR),
   and administration fees.
4. **Automated Bank Integration**: Direct synchronization / Open Finance bank feed imports.
5. **Tax Schedule Calculation**: Automated declining IOF / IR rate schedules or daily accrual engines.
6. **Lot-level Yield Allocation**: Distributing group return adjustments proportionally across
   multiple contributing piggy bank source lots.
