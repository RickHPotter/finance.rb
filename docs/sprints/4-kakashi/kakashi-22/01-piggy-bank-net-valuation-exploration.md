# KAKASHI-22 Piggy Bank Net Valuation and IOF: Product Exploration

## Status

This document records discovery and a recommended direction for later work. It is not
yet a locked product/data contract and does not authorize implementation.

The design must be revisited with real bank examples before development, especially
where the bank exposes gross balance, net redemption value, taxes, or only a final
settlement amount.

## Problem

The current Piggy Bank flow assumes that the user can explicitly record valuation
changes while money remains in a bank-managed savings pocket (`cofrinho`). The bank in
the motivating case creates two practical limitations:

1. it does not provide a useful daily profit history from which daily valuation entries
   can be copied; and
2. an IOF charge can consume most or all of the visible profit before each contribution
   completes its first 30 days, after which that IOF charge becomes zero and the
   accumulated profit becomes available.

The application must not manufacture daily financial history that the bank cannot
substantiate. It should accept sparse observations, preserve the difference between
principal and return, and avoid presenting gross yield as money that could actually be
redeemed.

The exact tax schedule is deliberately not defined here. Before the application ever
calculates IOF itself, the bank/product rules and their authoritative source must be
verified. The immediate design can use values observed from the bank without encoding
tax law.

## Existing Domain Behavior

KAKASHI-05 already provides most of the required accounting graph:

- a negative `PIGGY BANK` `CashTransaction` records money leaving the liquid account;
- a `PiggyBank` link stores the contribution's projected `return_date` and
  `return_price`;
- a positive, unpaid `PIGGY BANK RETURN` `CashTransaction` represents the projected
  money coming back;
- several contributions may attach to one open return group when they use the same bank
  entity;
- an `Investment` linked through
  `piggy_bank_return_cash_transaction_id` is a signed valuation delta;
- positive linked Investments increase the projected return and negative linked
  Investments reduce it;
- linked valuation Investments do not generate legacy aggregate investment cash
  transactions;
- paid return installments are preserved while later contributions or valuations
  change only the unpaid remainder;
- once recorded profit is required by paid history, destructive corrections are
  rejected;
- monthly analysis reports contributions, withdrawals, projected movements, and signed
  recognized Piggy Bank profit/loss separately from ordinary cash movement.

Relevant implementation surfaces include:

- `app/models/piggy_bank.rb`
- `app/models/investment.rb`
- `app/views/investments/form.rb`
- `app/views/investments/show.rb`
- `app/views/piggy_banks/contributions_sheet.rb`
- `app/services/logic/finder/monthly_analysis/piggy_banks.rb`

### Important Existing Semantics

Linked Investments are deltas, not balance snapshots. If principal is `1000.00` and a
linked valuation of `7.42` exists, the calculated return is `1007.42`. Entering a later
observed total of `1008.10` directly as another Investment would be wrong; the new delta
must be `0.68`.

The model does not require one valuation per day. Daily, monthly, ad hoc, maturity-day,
and settlement-only entries are all technically possible today.

### Existing Semantic Ambiguity

`PiggyBank#return_price` is currently editable and was originally described as the
expected or actual returned amount. At the same time, the valuation dashboard calculates
`principal` by summing the linked Piggy Bank records' `return_price` values, then adds
linked Investment deltas to produce the projected total.

If a user includes expected profit directly in `return_price` and later records that
same profit as a valuation Investment, the profit is counted twice. Before adding
snapshot reconciliation, the later contract must choose one authoritative meaning:

1. `return_price` is contributed principal and all yield/loss lives in valuations; or
2. `return_price` is an independently editable expected return, in which case it must
   not be labelled or calculated as principal.

The recommended direction is the first: initialize and retain each contribution's
baseline return at the contributed principal, then represent every observed gain or
loss as a signed valuation delta. Existing records with customized return prices would
need an inventory and explicit compatibility/backfill decision rather than silent
reinterpretation.

## Vocabulary for the Later Contract

| Term | Meaning |
| --- | --- |
| Principal | Sum of contribution amounts assigned to a Piggy Bank return |
| Gross accrued yield | Earnings shown before redemption taxes or fees |
| Estimated IOF | IOF that the bank would retain if the contribution were redeemed at the observation time |
| Net redeemable value | Amount the user could actually receive at the observation time |
| Recognized valuation | Signed delta already recorded through linked Investments |
| Recorded return total | Principal plus all recognized valuation deltas |
| Snapshot | A bank-observed total at a particular time, converted by the app into a signed delta |
| Maturity lot | One contribution with its own IOF-free date |
| Settlement | Actual withdrawal recorded by paying all or part of the generated return |

These meanings must remain distinct. In particular, a projected withdrawal date is not
automatically the same thing as the date on which one contribution becomes IOF-free.

## Recommended Immediate Accounting Policy

Use net redeemable value and sparse reconciliation.

The user records a valuation only when the bank provides a meaningful observable value.
The application should calculate the linked Investment delta from the entered snapshot:

```text
valuation delta = observed net redeemable value - currently recorded return total
```

If the difference is zero, no valuation entry is required.

### Example: Held Until Day 30

1. On August 1, deposit `1000.00`.
2. Record a paid `PIGGY BANK` source of `-1000.00`.
3. Its unpaid generated return starts at `1000.00`.
4. Before day 30, IOF makes the net redeemable value effectively `1000.00`; record no
   profit merely because the bank shows gross yield.
5. On day 30, the bank exposes a net redeemable value of `1007.42`.
6. Record one linked valuation delta of `+7.42`.
7. The generated return becomes `1007.42`.
8. If the money remains invested, leave the return unpaid. If it is withdrawn, reconcile
   the final observed amount first and then pay the applicable return installment.

All profit is recognized on the observation date. That is less granular than economic
daily accrual, but it is honest, explainable, and supported by evidence from the bank.

### Example: Early Redemption

1. Principal is `1000.00`.
2. The bank shows gross earnings, but the actual net redemption amount is `1000.35`
   after IOF and any other retained amount.
3. Reconcile the return to `1000.35`, creating a `+0.35` valuation delta.
4. Pay the generated return for the amount actually received.

If the net redemption amount is exactly the principal, no profit entry is created.

### Correction After a Previous Gross Valuation

If gross profit was already recorded, the existing signed-delta model can correct it:

```text
recorded return:       1007.42
net redeemable value:  1001.10
new valuation delta:     -6.32
```

This works today, but gross entries followed by negative IOF estimates produce noisy
history. Net-only reconciliation should be the default.

## Contribution Lots and the Grouped-Return Limitation

IOF age belongs to each contribution, not necessarily to the visible bank pocket as a
whole. A contribution on August 1 and another on August 20 can become IOF-free on
different dates.

The current grouped-return model has one shared return transaction and one authoritative
return date. A newly attached contribution inherits that group date. Consequently, a
single group cannot accurately express several independent IOF clocks.

Until this is modeled explicitly:

- create a new return group for contributions with different IOF-free dates;
- attach contributions only when they belong to the same maturity cohort or when the
  IOF distinction is irrelevant;
- allow the common entity and future dashboard/reporting layer to aggregate separate
  return groups into the bank's visible Piggy Bank total.

This is a safe operational workaround, not the ideal final UX.

## Return Date Versus IOF-Free Date

`PiggyBank#return_date` currently drives the generated cash-return projection. It means
the date on which the app expects money to return to the liquid account.

An IOF-free date means only that a contribution can be redeemed without IOF. The user
may keep the money invested after that date. Reusing `return_date` for both concepts
would create overdue projected withdrawals that were never intended to happen.

A fuller design should therefore consider a separate field such as:

- `iof_exempt_on`; or
- a more product-neutral `available_on` with an explicit availability reason.

The field belongs to the contribution link/lot, not the grouped return transaction.
No migration should be designed until the bank's lot behavior is confirmed.

## Product Options

### Option A: Sparse Net Snapshot Reconciliation — Recommended First

Add a `Reconcile valuation` action to a Piggy Bank return. The user enters the bank's
current net redeemable total, and the application creates the required signed linked
Investment delta.

Advantages:

- reuses the existing model and audit/rollback behavior;
- requires no daily bank history;
- avoids encoding tax law;
- prevents the user from manually calculating a delta;
- records only money that is actually available;
- supports maturity-day and final-settlement reconciliation.

Limitations:

- profit is attributed to observation dates rather than accrued daily;
- the user must obtain a net value from the bank;
- without an explicit maturity field, the app cannot alert on day 30 per contribution.

This option may require no schema change. The entered snapshot total can be converted
into the existing linked Investment record at the service boundary.

### Option B: Separate Gross Yield and Estimated Charges

Record gross yield as a positive valuation and IOF or other estimated charges as a
negative valuation. A day-30 adjustment reverses any remaining IOF estimate.

Advantages:

- exposes gross performance separately from liquidity cost;
- could support tax/fee reporting later.

Limitations:

- requires reliable gross and fee observations;
- produces more entries and correction noise;
- the current `Investment` model has no structured valuation kind, so descriptions
  would be carrying financial semantics;
- monthly analysis currently combines all signed adjustments into one recognized
  profit/loss total.

This option should not be implemented merely to simulate precision the bank does not
provide.

### Option C: Synthetic Daily Accrual — Not Recommended by Default

Given a final profit amount, the app could spread that profit backward across days.

This would create invented dates and amounts unless the bank supplies a reproducible
calculation basis. It would misrepresent evidence, complicate rollback, and make monthly
analysis look more precise than the underlying data. It should remain out of scope
unless the user explicitly chooses an estimation model and estimated rows are visibly
distinguished from observed rows.

## Potential Later Data Shape

The minimal snapshot workflow can reuse `Investment`, but a mature solution may need a
first-class immutable observation record. A possible model is
`PiggyBankValuationSnapshot`, containing:

- return group or contribution-lot reference;
- observation timestamp;
- observed net redeemable value;
- optional observed gross value;
- optional observed tax/fee amount;
- provenance (`manual`, import, bank integration, or calculation);
- the generated valuation Investment/delta;
- audit operation identity.

The snapshot would preserve what the bank displayed while the generated Investment
would remain the financial delta consumed by current projection and analysis code.

This model is not required for the first slice and should not be introduced until the
expected correction, deletion, and import workflows are known.

## UI Direction

The Piggy Bank return dashboard is the natural entry point. A conservative first UI
would show:

- contributed principal;
- recognized valuation adjustments;
- currently recorded return total;
- paid and unpaid return totals;
- `Reconcile valuation` action;
- a list of observed valuation entries;
- a clear explanation that the input is the total net amount currently redeemable,
  not today's profit.

When maturity lots exist, also show each contribution's:

- contribution date and principal;
- IOF-free/available date;
- current age/status;
- linked return group;
- whether its value is observed, estimated, or not yet known.

The form should preview the calculated delta before saving:

```text
Observed net value       R$ 1.007,42
Currently recorded       R$ 1.000,00
Valuation adjustment        R$ 7,42
```

A zero delta should result in an explicit no-change response rather than a zero-valued
Investment, because linked valuations currently require a nonzero price.

## Reporting Consequences

The existing Monthly Analysis classifies linked Investments as recognized Piggy Bank
profit/loss in the Investment's month. Under sparse reconciliation:

- a day-30 catch-up is recognized entirely in that month;
- an early-redemption correction is recognized on its correction/settlement date;
- no estimated daily income appears before an observation;
- contributions and withdrawals remain separate from ordinary income/outcome.

This is the desired first contract. If later reports require economic accrual rather
than observed recognition, that must be introduced as a separate reporting mode with
estimated values clearly labelled.

## Safety, Audit, and Rollback Requirements

Any future reconciliation flow should:

- scope the return group and valuation to the current user and context;
- lock the return group while calculating and applying the delta;
- calculate from integer cents and reject malformed or implausible totals;
- reject a resulting projection that is zero, negative, or below paid history;
- create the snapshot/valuation and synchronize the return within one database
  transaction and one root `AuditOperation`;
- preserve paid installments and change only the unpaid remainder;
- include generated projection changes under the existing `piggy_bank_sync` mutation
  source;
- remain previewable and reversible through guarded rollback;
- detect stale reconciliation when the recorded return changes between preview and
  apply;
- avoid rewriting user-entered valuation history merely because a dashboard is opened.

## Decisions Required Before Implementation

1. What does the bank expose at an arbitrary moment?
   - gross balance;
   - estimated net redemption amount;
   - gross profit and IOF separately;
   - or only a final amount after redemption?
2. Is the 30-day IOF clock tracked independently for every deposit?
3. Does an additional deposit affect only its own lot or change the bank pocket's
   displayed maturity behavior?
4. Is the app expected to track the day on which money becomes IOF-free even when no
   withdrawal is planned?
5. Should profit be recognized only when observable, or does the user want a visibly
   estimated accrual report?
6. Should the first reconciliation screen accept:
   - net redeemable total only; or
   - gross total plus taxes/fees?
7. When the bank exposes only a final amount, should the valuation and withdrawal be
   recorded in one atomic action?
8. May two lots with different maturity dates ever share one generated return, or must
   the app keep separate returns and aggregate them only for display?
9. Is IOF the only withheld amount relevant to the desired net figure, or should the
   language remain generic enough for other taxes and fees?

## Proposed Later Slices

These slices are exploratory and should be rewritten after the decisions above.

1. **Observed-value contract and regression coverage**
   - lock the meaning of principal, recorded total, observed net total, and signed delta;
   - cover positive, negative, zero, stale, partially paid, and settled cases.
2. **Net snapshot reconciliation service**
   - calculate and preview the delta;
   - create a linked Investment and synchronize the unpaid return atomically;
   - integrate audit and guarded rollback.
3. **Piggy Bank dashboard workflow**
   - add the reconciliation action, calculation preview, history, and localized help;
   - preserve mobile, dark-mode, and Turbo behavior.
4. **Contribution maturity lots**
   - add a separate availability/IOF-free date only if confirmed necessary;
   - prevent grouped returns from hiding incompatible lot clocks;
   - add maturity visibility without implying withdrawal.
5. **Optional structured gross/tax reporting**
   - introduce valuation kinds or immutable snapshots only if real bank data supports
     them;
   - keep observed and estimated values visibly separate.

## Recommended Starting Decision

Unless real bank evidence contradicts it, begin later work with Option A:

- treat the bank's net redeemable total as authoritative;
- accept sparse observations rather than daily history;
- calculate the signed delta automatically;
- preserve one IOF clock per contribution;
- do not compute IOF in the application;
- do not synthesize daily profit;
- keep maturity availability separate from projected withdrawal.

This direction uses the strongest parts of the current Piggy Bank model while avoiding
false precision and premature tax-domain complexity.
