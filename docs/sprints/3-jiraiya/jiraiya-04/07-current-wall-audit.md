# JIRAIYA-04 Current Wall Audit

## Purpose

This file records the current runtime wall matrix from code.

It is not a planning document.
It is a snapshot of what the guards actually do today.

Primary source:

- `app/models/concerns/has_financial_safety_guards.rb`

Secondary source:

- `app/models/concerns/cash_transactable.rb`
- `app/models/concerns/has_advance_payments.rb`
- `app/models/concerns/exchange_cash_transactable.rb`

## Confirmation-Required

- paid `CardTransaction` date correction inside the same `ref_month_year`
- paid `CashTransaction` current-month unpay
- paid `CashTransaction` adjacent month-boundary correction
- paid `EXCHANGE RETURN` price correction
- general paid amount rewrites when the change is installment-price-only and invariants still hold
- paid `CashTransaction` destroy
- paid `CardTransaction` destroy only when every affected billing cycle remains covered after removal

Card destroy coverage means:

- remaining cycle debt must stay greater than or equal to the remaining settled amount
- settled amount includes already-paid `CARD PAYMENT`
- settled amount includes already-paid `CARD ADVANCE`

## Directly Allowed

- pure shared paid / not-paid toggle on shared return flows
- actionable shared return correction from assistant replay/apply
- shared return structural edits after payment when the paid installments stay untouched and the future unpaid dates remain valid

## Hard-Blocked

- category/entity allocation changes after paid history
- paid installment rewrite that is not one of the confirmation candidates
- moving unpaid future installments onto or before the paid boundary
- parent financial-field rewrites that do not qualify as a historical correction candidate
- rewrite into an already-paid projection target
- counterpart paid-state sync when the counterpart cannot be resolved safely

## Guards Still Outside The Unified Confirmation Gate

These walls do not currently run through the same confirmation candidate logic in `HasFinancialSafetyGuards`.

- `CashTransactable`
  - paid projection rewrite
  - paid projection destroy only piggybacks on parent confirmed destroy
- `HasAdvancePayments`
  - paid advance rewrite
  - paid advance destroy only piggybacks on parent confirmed destroy
- `ExchangeCashTransactable`
  - paid projection rewrite except for its explicit unpaid-projection carve-out
  - paid projection destroy only piggybacks on parent confirmed destroy

## Removed Stale Key

`exchange_projection_locked` is intentionally not part of the current runtime wall matrix.

Reason:

- it remained in helper/locale mapping
- but it is not currently emitted by the active guard code
- the current exchange-return runtime no longer uses that one-way wording

## Next Audit Target

If the confirmation policy keeps expanding, the next useful step is to decide whether the three projection concerns should:

- be promoted into `confirmation-required`
- or remain explicitly `hard-block`

That choice should be made in code and then folded back into the docs.
