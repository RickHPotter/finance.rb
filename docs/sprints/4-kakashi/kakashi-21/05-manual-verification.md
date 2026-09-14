# KAKASHI-21 Manual Verification

## Purpose

Use this checklist against production-shaped development data before deployment. A
reference merge is a real audited financial mutation, so use records that may safely be
changed and take note of the selected user card, Context, source month, target month,
invoice IDs, installment IDs, and exchange-return projection IDs before submitting.

Use separate graphs for combine and reallocation unless the first operation is reverted
before the second test. Do not use paid production history merely to exercise a blocker.

## Shared Form and Navigation

1. Open a user card and choose the merge action for one unpaid reference.
2. Confirm neither mode is selected initially.
3. Read both choices before submitting:
   - **Combine into target** says the emptied source is removed and later invoices stay
     in their current months.
   - **Reallocate installments** says source and later persisted invoices move forward
     one month while installment dates and amounts remain unchanged.
4. Switch between English and Brazilian Portuguese and confirm both labels,
   consequences, field labels, and validation messages are localized.
5. Check light and dark mode at desktop and mobile widths. The month inputs and choices
   must stack without horizontal scrolling; text, selected state, disabled state, error
   text, Merge, and Cancel must remain readable.
6. Confirm Cancel returns to the same user-card destination and preserves its filtered
   `return_to` state.
7. Submit through normal HTML navigation and through a Turbo visit. Success must return
   to the user card without `Content Missing`; a rejection must keep the form visible.

## K21-M01 — Combine Into Target

Choose two adjacent unpaid references containing installments in both months.

1. Record the source and target reference/invoice IDs and every member installment.
2. Select **Combine into target** and submit.
3. Confirm the source reference and source `CARD PAYMENT` cash transaction are removed.
4. Confirm source installments now belong to the target invoice alongside its original
   installments.
5. Confirm installment IDs, parent CardTransactions, numbers, counts, dates, prices,
   allocations, and paid states did not change.
6. Confirm the target invoice and cash installment equal the sum of final membership.
7. Confirm every later invoice remains in its original billing month.

Repeat with source after target. Combine must remain available for the existing backward
adjacent workflow and must still leave all other months untouched.

## K21-M02 — Forward Reallocation and Year Boundary

Prefer a 12-installment transaction spanning January through December 2026, with August
as source and September as target.

1. Record all installment IDs, numbers, dates, prices, parent IDs, billing months, and
   invoice IDs.
2. Select **Reallocate installments** for August → September and submit.
3. Confirm installments 1–7 remain in January–July.
4. Confirm installment 8 moves to September, 9 to October, 10 to November, 11 to
   December, and 12 to January 2027.
5. Confirm each moved row advances exactly one calendar month and installments 8 and 9
   do not collapse into the same invoice.
6. Confirm IDs, numbers, counts, amounts, parent CardTransactions, and original
   installment dates are unchanged.
7. Confirm the August source reference/invoice is removed and the January 2027 tail is
   canonical and contains one matching cash installment.

## K21-M03 — Reallocation Graph Variants

Exercise the following with safe unpaid data:

- a one-installment purchase in the source month;
- a one-installment purchase in a later month;
- several independent purchases in one affected invoice;
- an empty calendar gap between occupied buckets;
- a destination/tail reference and empty invoice that already exist; and
- a destination/tail graph that must be created.

For every case, confirm each persisted row moves once, the original gap advances rather
than collapses, existing canonical IDs are reused, only missing tail rows are created,
every occupied month has exactly one invoice, and invoice totals equal membership.

## K21-M04 — Card-Bound Exchanges and Projections

Use affected invoices containing monetary `card_bound` exchanges in at least the source
and target months.

1. Record each Exchange ID, month/year/date, generated `EXCHANGE RETURN` cash
   transaction ID, amount, and cash-installment amount.
2. Run combine on one graph and reallocation on another.
3. In combine, confirm only source exchanges move to target.
4. In reallocation, confirm every affected exchange moves forward exactly one month.
5. Confirm exchange dates follow destination references.
6. Confirm an empty source projection disappears, destination projections remain
   canonical, and projection/cash-installment totals equal their attached exchanges.
7. Confirm cash-bound exchanges, another card, another Context, and unrelated rows are
   unchanged.
8. Confirm the merge itself neither creates an actionable message nor changes existing
   message delivery, pending, supersession, or auto-apply behavior.

## K21-M05 — Fail-Closed Inputs and History

For each rejection, record invoice/reference counts and the latest AuditOperation before
submitting, then confirm all are unchanged afterward.

1. Submit without choosing a mode and then with an unknown mode through an HTTP client.
2. Try malformed source/target months.
3. Select a backward or non-adjacent pair for reallocation. Confirm the option is
   disabled after editing the months. When the server returns the invalid form, confirm
   the submitted months and selected mode remain visible with precise feedback.
4. Try reallocation with a paid affected installment, paid affected invoice, paid
   exchange-return projection, duplicate affected invoice, or missing canonical root.
5. Refresh after each rejection and confirm no bucket, amount, relationship, balance,
   message, or audit mutation escaped.

## K21-M06 — Audit Preview, Rollback, and Conflict

Run this once after a fresh combine and once after a fresh reallocation.

1. Open the committed merge AuditOperation and choose **Preview rollback**.
2. Confirm the mode, user card, Context, source/target range, affected rows,
   dependencies, and recalculations are present and the preview is applyable.
3. Apply the rollback, providing historical confirmation only when the established
   AuditRollback policy requests it.
4. Compare the graph with the notes taken before the merge. IDs, attributes, invoice
   membership, references, exchanges, projections, amounts, dates, paid states,
   balances, and ordering must match.
5. Confirm the immutable merge operation remains and one linked rollback operation was
   added.
6. Submit the same rollback token again. It must resolve to the already committed
   rollback rather than compensate twice.
7. On a separate merged graph, change one affected future unpaid row after the merge.
   Reopen the preview and confirm it is conflicted. No prefix of the merge may be
   restored.

## Sign-off

- [ ] Shared form/navigation passes in English and Brazilian Portuguese.
- [ ] Light, dark, desktop, and compact layouts are readable and navigable.
- [ ] Combine preserves the inherited collapse behavior in both adjacent directions.
- [ ] Reallocation passes the 12-installment year-boundary example.
- [ ] One-off, multi-purchase, gap, reused-tail, and created-tail graphs reconcile.
- [ ] Card-bound exchanges and return projections remain canonical.
- [ ] Invalid, unsafe, paid, and stale graphs fail without mutation.
- [ ] Fresh rollback restores both modes exactly and stale rollback fails closed.
- [ ] Actionable-message behavior is unchanged.
- [ ] `bin/ci` passes on the deployment candidate.
