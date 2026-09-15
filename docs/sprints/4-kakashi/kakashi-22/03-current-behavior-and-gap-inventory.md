# KAKASHI-22 Current Behavior and Gap Inventory

## Inventory Date

2026-09-15, before KAKASHI-22 implementation.

## What Already Exists

### Financial graph

- `PiggyBank` links one source `PIGGY BANK` cash transaction to one generated
  `PIGGY BANK RETURN` cash transaction.
- Several contribution links may share one generated return.
- `PiggyBank#return_price` values and signed linked Investment values determine the
  generated return total.
- The return projection retains paid installments and replaces the unpaid remainder.
- Model and database constraints enforce positive contribution baselines and positive
  Piggy Bank return installments.
- User/context/entity compatibility and open-group eligibility are validated.

### Valuation

- `Investment#piggy_bank_return_cash_transaction_id` links a signed delta to a return
  group.
- Ordinary Investments must be positive; Piggy Bank valuations may be positive or
  negative but not zero.
- Creating, updating, or destroying a linked Investment resynchronizes the return.
- A delta that would make the projection non-positive or violate paid history is
  rejected.
- The Investment form can select an open Piggy Bank return and initializes the return's
  bank account and established Piggy Bank Investment type.

### UI and reporting

- Generated-return edit/show surfaces can list contributing sources and linked
  Investments.
- Investment detail shows baseline, adjustments, projected total, recorded total, paid
  total, sibling valuations, and status.
- Monthly Analysis separately reports contributions, withdrawals, projected
  withdrawals, and recognized signed profit/loss.
- Piggy Bank Health Check and repair infrastructure already detect malformed projection
  graphs.

### Audit and operations

- `PiggyBank`, `Investment`, `CashTransaction`, and `CashInstallment` are financially
  audited.
- Projection callbacks use the `piggy_bank_sync` mutation source.
- Piggy Bank and Investment rollback adapters already cover ordinary supported changes.
- Every mutating web request receives a root audit operation.

## Important Existing Arithmetic

`PiggyBank#sync_return_projection!` currently calculates:

```text
grouped total = sum(link.return_price) + sum(linked investment.price)
unpaid total  = grouped total - sum(paid installment.price)
```

It then writes the grouped total to the generated `CashTransaction` and the unpaid total
to the remaining unpaid installment. This is the correct projection boundary for a
new snapshot-generated delta.

## Gaps KAKASHI-22 Must Close

### G1: The user must calculate deltas manually

The existing Investment form accepts `price` as a signed change. It does not accept the
bank's observed balance and does not explain what baseline to subtract.

### G2: Partial withdrawals make the intuitive subtraction dangerous

The generated transaction's `price` is a lifetime total, whereas the bank's current
redeemable value describes money still invested. After a partial withdrawal, subtracting
the transaction price would incorrectly reverse paid history.

### G3: There is no write-free preview or stale token

The user cannot verify the calculated adjustment before applying it, and no dedicated
boundary proves that the return graph remained unchanged between calculation and save.

### G4: The observed total is not represented in operation metadata

Investment stores the financial delta. The original balance observation and calculation
inputs are not named as one reconciliation event in current audit metadata.

### G5: IOF maturity is conflated with withdrawal scheduling

`PiggyBank#return_date` controls the projected cash return. It cannot truthfully say
when each contribution becomes IOF-free if several lots share one return or remain
invested after maturity.

### G6: No contribution-level maturity display exists

The contribution sheet can show source transactions, but it has no independent
availability date or waiting/available status.

### G7: Zero-change observations have no explicit workflow

Linked Investments reject zero correctly, but the UI cannot acknowledge that a bank
observation already matches the recorded remaining balance.

### G8: Final settlement is procedural rather than atomic

Today the user must record any last delta before paying the final return installment.
An atomic reconcile-and-settle workflow does not exist and remains outside the initial
contract unless bank evidence shows it is required.

## Compatibility Risks

1. `return_price` historically allowed a customized expected amount. Treating every
   stored value as source principal would silently change existing meaning.
2. Linked Investment callbacks already lock and save the generated return. A new service
   must establish a deterministic outer lock without deadlocking or duplicating sync.
3. A reconciliation after partial payment is valid only when based on the unpaid
   projection, not the parent transaction total.
4. The Piggy Bank Investment type may be missing or renamed in some databases; apply
   must fail with an actionable configuration error rather than choose an unrelated
   type.
5. Turbo double submission or retry must not create the same delta twice.
6. Rollback recognition must cover the real root operation, including its linked
   Investment and projection versions, rather than only synthetic adapter fixtures.

## Expected Implementation Surfaces

- `app/models/piggy_bank.rb`
- `app/models/investment.rb`
- a focused reconciliation preview/apply service under `app/services/`
- a narrow authenticated reconciliation controller and routes
- Piggy Bank return dashboard and contribution-sheet Phlex views
- localized controller/model/view copy in English and Portuguese
- request, service, model, reporting, concurrency, and rollback specs
- a migration only for the approved contribution-level availability field

The normal Investment form remains intact. Exchange, friendship, conversation,
actionable-message, and shared-ledger code are not expected implementation surfaces.
