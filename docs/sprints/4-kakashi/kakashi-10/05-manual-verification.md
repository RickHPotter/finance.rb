# KAKASHI-10 Manual Verification

## Purpose

Use this checklist after refreshing development from production and before deploying
KAKASHI-10. The checks are intentionally read-only: opening, filtering, charting, and
following a source must not alter a transaction, installment, audit, message, balance,
or projection.

Record the resource IDs and months used during the run. Prefer one populated example
and one empty example for every surface.

## Shared Checks

Repeat these checks wherever a report is present:

1. Open the owning show page and confirm its ordinary summary renders before the lazy
   report finishes loading.
2. Confirm the loading panel occupies stable space and is replaced by either report
   content or an empty state.
3. Change every available filter. Confirm the address bar preserves the selected
   state and a refresh restores it.
4. Change filters quickly twice. Confirm only the final selection remains visible.
5. Compare each summary amount with its ordered textual list and chart point.
6. Follow every displayed Cash and Card source link. Confirm the destination contains
   the reported rows and Back returns to the same resource and report state.
7. Confirm money uses `R$ 1,000.00` / `R$ -75.00` in English and
   `R$ 1.000,00` / `R$ -75,00` in Brazilian Portuguese.
8. Repeat at a narrow mobile width and in light and dark mode. Controls must stack,
   text and charts must remain legible, and the page must not scroll horizontally.
9. With browser request blocking enabled for the JSON endpoint, confirm a localized
   error and Retry button appear. Re-enable the request and confirm Retry succeeds.
10. Navigate away while a report request is loading. Confirm no late content or
    JavaScript error appears on the destination page.

## Category and Entity Trends

Pages: `/categories/:id` and `/entities/:id`.

- Use a range containing cash and card installments, income and outcome, paid and
  pending rows, and at least one empty month.
- Confirm the anchor category/entity includes a multi-allocation transaction once.
- Confirm counterpart bundles retain all categories/entities in deterministic order.
- Toggle Paid, Pending, Income, Outcome, Day, and Month. Compare their totals with All.
- Confirm empty days/months remain visible as zero buckets.
- Confirm Cash and Card source subtotals add to each mixed total.
- Confirm category colors are identical in chart labels and textual rows.
- On Category show, confirm the Entities pie is present and contains only Entities from
  the selected category and current context.
- On Entity show, confirm the Categories pie is present, uses accessible category
  colours, and contains only Categories from the selected entity and current context.
- Filter each reciprocal pie by one bank account and one user card, then restore Select
  All. Confirm its legend and slices follow the selected sources.
- Change the bounded trend filters and confirm the reciprocal pie retains its complete
  current-context allocation overview rather than silently adopting the trend range.

## Bank Account Movement

Page: `/user_bank_accounts/:id`.

- Confirm ordinary income/outcome, transfer/return, Piggy Bank, and generated
  card-payment rows appear only in their documented movement family.
- Confirm paid-state filtering follows cash installments, including a mixed-state
  transaction.
- Confirm the displayed current/first/latest recorded balances are context only and
  are not recomputed by the report.
- Confirm an account belonging to another context cannot be requested by changing the
  report ID.
- In both restored interactive dashboards, switch the primary category/entity,
  select one combination, select all combinations, and select/unselect secondary
  series. Confirm the chart and textual totals follow the current bounded report
  filters.

## User Card Movement

Page: `/user_cards/:id`.

- Use a purchase with several installments and confirm each appears in its billing
  period, not merely in the purchase month.
- Confirm purchase date, installment date, billing period, closing date, and due date
  keep distinct labels.
- Confirm paid-state filtering follows card installments.
- Confirm advances, invoices, and generated payment identities remain explicit.
- Confirm the generated cash payment is not counted as a second card expense.
- Repeat the category-first and entity-first interactive selections. Confirm their
  points follow billing periods and that Select All is server-reconciled.

## Budget Performance

Page: `/budgets/:id`.

- Check a budget with no movement, cash only, card only, and mixed cash/card movement.
- Confirm Cash plus Card equals Actual and Definition minus Actual equals Remaining.
- Check inclusive, exclusive, and first-installment-only budgets against their
  existing matched-transaction lists.
- Confirm utilization and period completion are separately labelled and may differ.
- Check an exceeded budget: utilization may exceed 100 and remaining stays truthful.
- Open every source chunk and confirm its amount and unique installment count.
- Confirm an inactive historical budget remains fully readable and read-only.

## Monthly Analysis Transfers and Piggy Banks

Page: `/balances?tab=monthly_analysis&month=YYYY-MM`.

- Move backward and forward by month and refresh. Confirm the URL and month control
  stay synchronized.
- Confirm ordinary totals exclude exchange families, failed returns, Piggy Bank rows,
  and generated card-payment cash.
- Check sent EXCHANGE, received EXCHANGE RETURN, and sent BORROW RETURN rows. Confirm
  the displayed source opens the exact record and returns to the selected month.
- Confirm Failed totals equal the textual failed rows and continue using the existing
  `starting_price` rule.
- For a shared exchange pair, confirm only the current-context side contributes.
- Check Piggy Bank contributed, projected contribution, withdrawn, projected
  withdrawal, and recognized profit/loss separately.
- Open Piggy Bank return and valuation sources and confirm generated/source identity
  is labelled correctly.

## Mutation Regression

After completing the read checks, perform one ordinary edit in each existing workflow
below and undo it where appropriate:

- cash transaction edit and installment payment;
- card transaction edit and installment payment;
- budget allocation edit;
- shared exchange correction/auto-apply using an already-covered scenario; and
- actionable-message read/mute/revert eligibility check.

The reports may reflect committed changes after refresh, but KAKASHI-10 must not alter
how any mutation is sent, applied, audited, corrected, superseded, or reverted.

## Sign-off

- [ ] Shared checks pass in English and Brazilian Portuguese.
- [ ] Category and Entity trends reconcile.
- [ ] Category and Entity reciprocal allocation pies remain present and context-scoped.
- [ ] Bank Account and User Card movement reconcile.
- [ ] Budget Performance reconciles.
- [ ] Monthly Analysis transfers, failed returns, and Piggy Banks reconcile.
- [ ] Mutation regression shows no behavior change.
- [ ] `bin/ci` passes on the deployment candidate.
