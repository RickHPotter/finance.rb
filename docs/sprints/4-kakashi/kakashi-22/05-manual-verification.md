# KAKASHI-22 Manual Verification

## Purpose

Use this checklist against production-shaped development data before deployment. A Piggy
Bank net reconciliation creates a real linked Investment, synchronizes generated return
installments, and records an audited financial operation. Use records that may safely be
modified, and note the selected User, Context, Return Cash Transaction ID, source Cash
Transaction IDs, Piggy Bank IDs, created Investment ID, and Audit Operation ID before
submitting.

Do not use paid production history merely to trigger an error. When testing rollbacks,
verify that compensation executes atomically and restores the exact pre-reconciliation
financial graph.

---

## Shared Form, Cards, and Navigation

1. Open a generated Piggy Bank return cash transaction detail view (`/cash_transactions/:id`).
2. Confirm the **Valuation and Reconciliation** section is displayed:
   - Displays the current recorded remaining net total.
   - Lists any existing linked Investment valuation adjustments.
   - Provides the **Reconcile Valuation** action button (`/cash_transactions/:id/piggy_bank_reconciliation/new`).
3. Click **Reconcile Valuation** to open the reconciliation interface:
   - Current recorded remaining net is displayed as the baseline comparison amount.
   - Form contains **Observed Net Value** (currency input) and **Observation Date** (date input).
   - Form initially displays a blank or default state without an auto-applied adjustment.
4. Test preview interaction:
   - Entering an observed amount and selecting preview calculates and renders the
     **Preview Card** via Turbo without persisting database writes.
   - Preview displays Recorded Unpaid, Observed Net, and the signed Adjustment Delta
     (with formatted currency and directional indicator).
   - Preview computes a cryptographic SHA256 digest tying inputs to the locked graph.
5. Switch between English (`en`) and Brazilian Portuguese (`pt-BR`):
   - Confirm form labels, helper text, calculation summary, IOF availability badges,
     flash messages, and error keys are fully localized.
6. Check light and dark mode at desktop (>= 1024px) and mobile (< 640px) viewport widths:
   - Preview card, monetary figures, badges, inputs, and action buttons stack cleanly
     without horizontal scrolling.
   - Contrast, focus rings, disabled buttons, and alert surfaces meet accessibility guidelines.
7. Test Cancel and navigation paths:
   - Clicking Cancel returns cleanly to the return cash transaction show view.
   - Preservation of `return_to` parameter on successful apply returns the user to the
     originating balance or report view.

---

## K22-M01 — Day-30 Catch-Up (Positive Delta)

Exercise standard monthly valuation catch-up on a matured or day-30 reserve.

1. Select an open Piggy Bank return with recorded unpaid balance of R$ 1,000.00.
2. Open the reconciliation form and set:
   - Observed Net Value: `1007.42` (R$ 1,007.42)
   - Observation Date: Day 30 date (e.g., 30 days after contribution)
3. Trigger Preview:
   - Recorded Unpaid: R$ 1,000.00
   - Observed Net: R$ 1,007.42
   - Adjustment Delta: `+R$ 7.42`
4. Submit the reconciliation:
   - Form redirects with HTTP `303` to the return transaction detail view with a localized
     success notification.
5. Verify persisted records:
   - Exactly one linked `Investment` created with amount `+7.42`, dated on the observation date,
     categorized as built-in Piggy Bank investment type.
   - Return Cash Transaction `price` updated to `1007.42`.
   - Single unpaid `CashInstallment` updated to `1007.42`.
   - Exactly one `AuditOperation` created with `operation_kind: "piggy_bank_net_reconciliation"`.

---

## K22-M02 — Downward / Negative Correction

Exercise downward correction resulting from post-IOF withholding or valuation dip.

1. Use a return with recorded unpaid balance of R$ 1,007.42.
2. Enter an observed net value of `1001.10` (R$ 1,001.10) with observation date.
3. Trigger Preview:
   - Adjustment Delta shows `-R$ 6.32` with a downward adjustment notice.
4. Submit the reconciliation:
   - Redirects to return detail with success message.
5. Verify persisted records:
   - Exactly one linked `Investment` created with amount `-6.32`.
   - Return transaction `price` and unpaid installment updated to `1001.10`.
   - Return detail valuation list displays the negative adjustment alongside earlier valuations.

---

## K22-M03 — Partial Withdrawal Baseline Preservation

Exercise reconciliation on a reserve where a partial redemption has already been settled.

1. Select a Piggy Bank with R$ 5,000.00 total initial principal.
2. Perform a partial payment split on the return transaction:
   - Installment 1: R$ 1,000.00 marked **paid** (settled withdrawal).
   - Installment 2: R$ 4,000.00 remaining **unpaid** (pending projection).
3. Open the reconciliation form:
   - Baseline comparison shows R$ 4,000.00 (the unpaid remainder, NOT the lifetime R$ 5,000.00).
4. Enter observed net of `4050.00` (R$ 4,050.00).
5. Trigger Preview:
   - Recorded Unpaid: R$ 4,000.00
   - Observed Net: R$ 4,050.00
   - Adjustment Delta: `+R$ 50.00`
6. Submit:
   - Paid installment (R$ 1,000.00) remains completely untouched with its original ID, date,
     price, and paid flag.
   - Unpaid installment updated to R$ 4,050.00.
   - Lifetime return transaction `price` equals R$ 5,050.00 (sum of paid 1,000.00 + unpaid 4,050.00).
   - Monthly Analysis reflects R$ 10.00 withdrawn and R$ 0.50 recognized profit/loss.

---

## K22-M04 — Zero Difference / No-Op

Exercise reconciliation when the bank observation exactly matches the system state.

1. Select an open return with recorded unpaid balance of R$ 1,007.42.
2. Enter observed net of `1007.42`.
3. Trigger Preview:
   - Recorded Unpaid: R$ 1,007.42
   - Observed Net: R$ 1,007.42
   - Adjustment Delta: `R$ 0.00` with informational note that no adjustment is required.
4. Submit:
   - Redirects to return detail with localized notice that valuation already matches recorded total.
   - Verify zero database writes: NO Investment created, NO installment modified, NO AuditOperation logged.

---

## K22-M05 — Stale Preview and Concurrency Protection

Exercise optimistic concurrency and stale digest protection.

1. Open the reconciliation form in Tab A for a return with balance R$ 1,000.00.
2. Generate Preview for observed net `1050.00`.
3. In Tab B, create a manual linked Investment of R$ 10.00 or modify the return installment.
4. Return to Tab A and click Apply without re-previewing:
   - The apply service rejects the stale digest (`reason_code: :stale_preview`).
   - Renders a warning that the underlying financial data changed since preview.
   - Zero inconsistent mutations are committed.

---

## K22-M06 — Contribution IOF Availability Clocks and Badges

Exercise contribution availability tracking and isolation from return scheduling.

1. Create a new Piggy Bank contribution dated 2026-06-15:
   - Verify form suggests `iof_exempt_on` default of `2026-07-15` (date + 30 calendar days).
   - Submit and verify the contribution shows `iof_exempt_on = 2026-07-15`.
2. View Return Detail (`/cash_transactions/:id`) and Contributions Sheet:
   - Displays lot contribution date, baseline amount, availability date, and status badge:
     - Date in future: **Waiting** badge (`waiting` / `Aguardando`).
     - Date today or past: **Available** badge (`available` / `Disponível`).
3. Create a grouped contribution to the same return on a later date (e.g., 2026-07-01):
   - Verify each contribution lot maintains its own independent availability date and status badge.
4. Edit contribution to clear the availability date:
   - Verify lot displays **Not Recorded** badge (`not_recorded` / `Não informado`).
5. Confirm schedule isolation:
   - Changing `iof_exempt_on` does NOT alter `return_date`, `return_price`, or cash installments.

---

## K22-M07 — Audit and Rollback Verification

Exercise single-operation auditable commit and guarded rollback recovery.

1. Execute a reconciliation applying a `+R$ 15.00` adjustment on an open return.
2. Query or view the resulting `AuditOperation`:
   - `operation_kind` is `piggy_bank_net_reconciliation`.
   - Versions recorded: `Investment` create version (source: `web`), `CashTransaction` update version
     (source: `piggy_bank_sync`), and `CashInstallment` update version (source: `piggy_bank_sync`).
   - Audit metadata contains `return_cash_transaction_id`, `observed_net_cents`, `recorded_remaining_cents`,
     `delta_cents`, and `digest`.
3. Navigate to Audit Rollback preview for this operation:
   - Rollback preview identifies the operation as eligible with clean compensation plan.
4. Confirm Rollback:
   - The linked `Investment` is deleted / compensated.
   - Return transaction `price` and unpaid installment amounts revert to exact pre-reconciliation values.
   - Repeat rollback attempt is rejected as already rolled back (idempotent).

---

## K22-M08 — Reporting & Monthly Analysis Integration

Exercise reporting recognition across source and observation months.

1. Contribution made in Month 6 (June) of R$ 5,000.00.
2. Valuation reconciled in Month 7 (July) with observed net R$ 5,074.00 (`+R$ 74.00` delta).
3. Open Monthly Analysis for Month 6 (`/balances?month=2026-06&tab=monthly_analysis`):
   - Piggy Banks total contributed: R$ 50.00 (in R$).
   - Recognized profit/loss: R$ 0.00.
4. Open Monthly Analysis for Month 7 (`/balances?month=2026-07&tab=monthly_analysis`):
   - Piggy Banks total contributed: R$ 0.00.
   - Recognized profit/loss: `+R$ 0.74`.
   - Group return entry displays source link pointing to `/investments/:id` for the valuation.
   - Clicking the valuation source navigates directly to the Investment show page.

---

## Sign-Off Checklist

| Scenario | Date | Tester / Environment | Result (Pass/Fail) | Notes |
| --- | --- | --- | --- | --- |
| K22-M01: Day-30 Catch-Up | | | | |
| K22-M02: Downward Correction | | | | |
| K22-M03: Partial Withdrawal | | | | |
| K22-M04: Zero Delta No-Op | | | | |
| K22-M05: Stale Preview Guard | | | | |
| K22-M06: IOF Availability Lots | | | | |
| K22-M07: Audit & Rollback | | | | |
| K22-M08: Monthly Analysis | | | | |
| Localization (EN & PT-BR) | | | | |
| Responsive & Dark Mode | | | | |
