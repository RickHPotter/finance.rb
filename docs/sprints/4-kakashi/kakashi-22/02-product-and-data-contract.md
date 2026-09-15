# KAKASHI-22 Piggy Bank Reconciliation: Product and Data Contract

## Status

Approved contract as of 2026-09-15. It promotes the recommended sparse net-value
direction from the exploration document into an implementation plan. The bank exposes
a current net redeemable total before withdrawal, and contribution IOF-free dates use
an editable 30-calendar-day default.

## Goal

Make a Piggy Bank useful when the bank does not expose a trustworthy daily earnings
history and IOF makes gross yield differ from the amount currently redeemable.

The user records what the bank can substantiate at a point in time. The application
calculates the signed valuation adjustment, updates only the unpaid return projection,
and preserves the observation as ordinary audited Piggy Bank valuation history.

## Non-Goals

KAKASHI-22 does not:

- calculate IOF, income tax, yield, CDI, interest, or any other bank formula;
- invent or spread daily profit backward across dates;
- treat gross yield as available money;
- import statements or integrate with a bank API;
- allocate group-level profit among individual contribution lots;
- rewrite paid return installments or completed withdrawals;
- reinterpret or backfill existing `PiggyBank#return_price` values;
- change ordinary Investment aggregation or exchange/actionable-message behavior.

## Vocabulary

| Term | Contract meaning |
| --- | --- |
| Contribution baseline | One `PiggyBank#return_price`; normally the contributed principal, but legacy customized values retain their stored meaning |
| Group baseline | Sum of contribution baselines linked to one generated return |
| Recognized adjustment | Signed sum of linked Piggy Bank `Investment#price` values |
| Lifetime recorded return | Group baseline plus every recognized adjustment, including amounts already withdrawn |
| Paid return | Sum of paid installments on the generated return |
| Recorded remaining value | Sum of unpaid installments; equivalently lifetime recorded return minus paid return in a healthy graph |
| Observed net redeemable value | Current amount the bank says can be withdrawn from the still-invested balance after applicable withheld charges |
| Reconciliation delta | Observed net redeemable value minus recorded remaining value |
| Availability date | Contribution-level date associated with becoming redeemable without IOF; it is not a promised withdrawal date |

The input is a balance snapshot, not today's profit and not the Piggy Bank's lifetime
return. This distinction matters after a partial withdrawal.

## Authoritative Calculation

All money calculations use integer cents.

```text
recorded remaining value = sum(unpaid return installments)
reconciliation delta     = observed net redeemable value - recorded remaining value
new lifetime return      = current lifetime recorded return + reconciliation delta
new unpaid projection    = observed net redeemable value
```

Example before any withdrawal:

```text
group baseline                  R$ 1,000.00
existing recognized adjustment     R$ 7.00
recorded remaining value        R$ 1,007.00
observed net redeemable value   R$ 1,009.25
new adjustment                     R$ 2.25
```

Example after a partial withdrawal:

```text
lifetime recorded return        R$ 1,007.00
already paid                    R$   200.00
recorded remaining value        R$   807.00
observed net redeemable value   R$   810.50
new adjustment                     R$ 3.50
```

The second calculation must not compare the bank's current balance with `R$ 1,007.00`.
Doing so would reverse previously withdrawn money.

## Reconciliation Lifecycle

### Entry Point

The generated `PIGGY BANK RETURN` detail surface is authoritative for the group. It
shows principal/baseline, recognized adjustments, paid return, recorded remaining
value, and the contribution list before offering `Reconcile valuation`.

The action is unavailable for foreign-context records, invalid projection graphs, or a
fully settled group with no unpaid return. A final amount should be reconciled before
the return is marked fully paid unless a later explicitly approved atomic settlement
flow is added.

### Preview

The user supplies:

- observation date;
- observed net redeemable value;
- an optional description or note.

The server resolves the user/context-owned return and presents:

- recorded remaining value;
- observed net redeemable value;
- calculated signed adjustment;
- resulting lifetime recorded return;
- paid amount that will remain untouched.

Preview performs no domain or audit write. It returns a digest/fingerprint derived from
the return group, relevant contribution links, linked valuations, and return
installments so apply can reject stale previews.

### Apply

Apply opens one database transaction and locks the return group before recalculating
the preview. If the fingerprint or submitted calculation is stale, it rejects without
creating an Investment or changing the projection.

A nonzero delta creates one linked `Investment`:

- user and context come from the return group;
- `piggy_bank_return_cash_transaction_id` is the reconciled return;
- `price` is the calculated signed delta;
- `date`, `month`, and `year` come from the observation date;
- bank account defaults to the generated return's account;
- Investment type uses the established Piggy Bank valuation type;
- description identifies an observed net-value reconciliation without pretending the
  delta is daily yield.

The existing Investment/Piggy Bank projection path then synchronizes the unpaid return.
Creation and synchronization belong to the same root `AuditOperation`.

### Zero Delta

When observed and recorded remaining values are equal, apply returns a successful
no-change outcome. It creates no zero-valued Investment and no empty audit operation.
The UI explains that the recorded Piggy Bank already matches the observation.

### Negative Delta

A negative delta is valid when the resulting lifetime return remains positive and the
result does not rewrite paid history. It may represent IOF, another withheld charge, a
loss, or correction of a previous gross valuation; KAKASHI-22 does not infer which.

## Validation and Safety

Reconciliation rejects:

- blank, malformed, zero, or negative observed current balances;
- a target outside the current user and context;
- a record that is not a canonical generated Piggy Bank return;
- a fully settled return with no unpaid installment;
- a broken graph whose stored return does not reconcile with its installments;
- a result that would reduce lifetime return to the paid amount or below;
- missing required Piggy Bank Investment configuration;
- a stale preview;
- concurrent change detected after locks are acquired.

The operation preserves paid installments byte-for-byte. Existing paid-history guards
remain authoritative, and a service failure rolls back the Investment, projection,
installment, balance, and audit versions together.

## Audit and Rollback

The committed root operation records scalar metadata including:

- operation kind (`piggy_bank_net_reconciliation`);
- return transaction ID;
- context and user IDs;
- observation date;
- recorded remaining cents;
- observed net cents;
- calculated delta cents;
- preview digest.

The generated Investment is a normal financially audited record. Projection mutations
remain tagged with `piggy_bank_sync`. The resulting operation must be previewable by
the existing rollback system and restore the complete pre-reconciliation graph or
nothing.

Later edits to the Investment, contribution links, or affected return/installments make
the rollback preview conflicted under the existing rules.

## Contribution-Level Availability

Availability belongs to each `PiggyBank` link because contributions can begin their IOF
clock on different dates while sharing one visible return group.

The proposed persistent field is nullable `PiggyBank#iof_exempt_on` (date). It is
informational and independently editable before protected paid-history boundaries. It
does not:

- alter `return_date`;
- move a cash installment;
- close or settle a group;
- determine the reconciliation delta;
- claim that withdrawal will happen on that date.

The return dashboard lists each contribution's contribution date, baseline, IOF-free
date, and status (`not recorded`, `waiting`, or `available`). Separate lots may continue
to share a return group because reconciliation observes the bank's group-level net
balance. KAKASHI-22 does not apportion that balance or its delta across lots.

For new contributions, the app proposes the source transaction's calendar date plus 30
calendar days. The user may edit or clear that date. No tax rate or declining IOF
schedule is stored or calculated.

## Reporting Contract

Linked Investments continue to appear as recognized Piggy Bank profit/loss in the
Investment's observation month. Therefore:

- day-30 catch-up profit appears on day 30's month;
- an early-redemption adjustment appears on its observation date;
- no estimated income appears before an observation;
- paid contributions and withdrawals remain separate from recognized valuation;
- the dashboard may label these values as observed/recognized, never accrued daily.

Existing monthly analysis arithmetic is retained. KAKASHI-22 adds regression coverage
for reconciliation-created Investments rather than creating another reporting ledger.

## Compatibility

The current application permits `PiggyBank#return_price` to differ from the source
transaction's absolute price. KAKASHI-22 does not silently decide whether such a value
is principal or an expected return.

- existing values remain unchanged;
- the reconciliation baseline is the persisted graph, not a recomputed source amount;
- new contributions retain the existing opposite-sign default;
- any future normalization/backfill requires an inventory, preview, explicit user
  choice, and its own audited operation.

The refreshed development database contained four links on 2026-09-15 and none differed
from its source transaction's absolute price. This observation informs risk but is not
a migration guarantee.

## UI Contract

The flow must work in English and Portuguese, mobile and desktop, light and dark mode,
and normal HTML/Turbo navigation.

Money fields use the shared locale-aware display/input conventions. The preview keeps
the currency sign placement consistent with the rest of the app. Validation failures
use stacked detailed notifications and retain the submitted observation.

No generic Investment form field is repurposed into a balance input. Manual linked
Investment entry remains available as the advanced signed-delta workflow; the new
reconciliation form is the safe snapshot workflow.
