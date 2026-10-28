# NARUTO-05 — Prepaid cards: product and data contract

## Scope update

Debit is deferred from the user-facing V1: the new-card form offers credit and prepaid only. Existing debit cards remain visible and editable, and their existing backend behavior remains in place for compatibility; direct API/model creation is not disabled. That behavior does not check or deduct the linked bank balance and is not supported as complete debit functionality. Future debit work must establish available-balance checks and deduction/reconciliation. The debit details below describe the retained implementation, not a V1 acceptance requirement.

The user has exercised a prepaid purchase and confirmed that it does not change the bank balance. Broader manual acceptance remains outstanding.

## Status and intent

V1 implementation is ready for manual testing as of 2026-10-20. This is the contract for a credit-card-safe V1, not a claim that noncredit card balances work or that manual testing has passed. Track verification in the [slices](02-implementation-slices.md).

An existing `UserCard` is a credit card: buying with it selects a billing `Reference` and `CardInstallment` projects an invoice-like `CashTransaction`. A VA/VR, gift, transport, or debit card has no credit bill. NARUTO-05 adds `credit`, `prepaid`, and `debit` kinds without changing historical credit behavior.

## Locked V1 decisions

| Concern | Credit | Prepaid | Debit |
|---|---|---|---|
| Billing `Reference` and closing/due dates | Existing behavior | None | None |
| Invoice-like cash projection from an installment | Existing behavior | None | None |
| Installments per purchase | Existing behavior | Exactly one | Exactly one |
| Minimum spend | Required as today | Not applicable (`nil`) | Not applicable (`nil`) |
| Bank account association | None | None in V1 | Required, owned by the same user |
| Bank balance mutation on purchase | Existing invoice flow | None | None in V1 |
| Card kind changes once used | Blocked | Blocked | Blocked |

“Used” means the card has any `CardTransaction` or `Reference`, including records in another context. A new or unused card may change kind after its target-kind fields validate. Do not silently convert a historical credit card's invoices or delete its references. All existing cards migrate to `credit` without rewriting transactions.

The debit bank account is descriptive routing data in this slice, **not** a second posting. Saving a debit purchase creates only the card transaction and its single installment; it does not create a linked ordinary cash transaction or deduct from `UserBankAccount.balance`. Do not label the resulting bank balance as including debit purchases. NARUTO-06 must design the reconciliation/deduction policy before using that association for totals.

`min_spend` is credit-only. A prepaid/debit purchase dated in the future is a planned entry and starts unpaid; one dated today or earlier follows the existing date-based paid default. Passing the future purchase date must **not** silently mark a planned purchase paid: the user confirms it through the existing paid-state action. This avoids treating a forecast as a completed purchase. The one-installment rule applies to planned purchases too.

## Data and invariants

- Add string-backed `user_cards.card_kind`, non-null with database default `credit`, constrained to `credit`, `prepaid`, `debit`. Keep the Ruby enum string-backed. Credit is the default for old rows and for omitted form/API values.
- Add nullable `user_cards.user_bank_account_id` FK. Require it only for debit; reject a foreign-user account. A prepaid or credit card must not retain a stale bank-account association when switching kind. Check user ownership server-side; the form is not a security boundary.
- Allow `due_date_day`, `days_until_due_date`, `credit_limit`, and `min_spend` to be null for noncredit cards. Credit still validates them and valid billing-day/range semantics. Preserve actual stored values on old credit cards. Noncredit cards clear these fields to `nil`, never sentinel zeroes; the existing `min_spend` database constraint and model validation must change accordingly.
- No `Reference` may be created for a noncredit card, including via create, edit, duplication, nested installments, date/user-card refresh, subscription links, exchange/card-bound flows, and internal services. The model's reference/date helpers should reject unsupported use clearly rather than return a misleading billing date. Guard every caller.
- No noncredit `CardInstallment` may attach to or create the invoice-style `CashTransaction`. Keep `cash_transaction_id` null. The existing `CashTransactable` callbacks must be skipped for noncredit installments, not merely the reference lookup. Do not remove unrelated ordinary cash transactions or weaken paid-history safeguards for credit.
- A noncredit `CardTransaction` and its one installment use the **purchase date's** month/year as their tracking period, not a credit reference month. Their date and amount remain visible in card index/search/reporting. Document how context and card filters partition them; they must never enter credit invoice totals or credit-limit calculations.
- Enforce one installment at the model/request boundary, including nested attributes and updates. A disabled UI control is insufficient. A credit transaction can still have its existing multi-installment schedule. Reject switching a transaction between credit and noncredit cards when existing installment, reference, projected-cash, paid-history, or exchange links cannot be migrated safely; do not silently drop linked records.
- Card-bound exchanges require a credit billing cycle. Reject them on prepaid/debit transactions with a localized validation message; standalone exchanges remain available. The form must not offer a misleading card-bound option for noncredit cards.
- Audit card-kind and bank-account routing changes. Rollback preview/apply must preserve the kind lock, dependency checks, and recalculation behavior. A rollback must not recreate a noncredit invoice or reference.

## UI and API contract

The new-card form offers localized Credit and Prepaid choices. Credit keeps billing, limit, and existing card-specific fields. Prepaid hides billing and bank-account fields. Existing debit cards retain their bank-account field. Edit/show/index clearly identify kind. Show a truthful “spending recorded; balance/top-ups not tracked yet” treatment for prepaid; do not present spent amount as remaining balance. Credit-only reference dates, unpaid invoices, limit, and payment actions must be hidden or unavailable for noncredit cards, including direct endpoints.

Card transaction forms accept any active card but adapt to kind. For prepaid/debit, render one installment and no invoice/reference picker, closing date, or billing refresh. Changing card or date updates the visible date/period without calling credit reference helpers. Desktop and PWA must agree. The transaction list remains filterable by card/context and displays the noncredit purchase date and paid state truthfully; a future planned entry must remain visibly unpaid until confirmed, not auto-complete when its date arrives. Existing credit screens retain their current behavior. Server responses for invalid kind/account/installment combinations are localized and actionable.

The `UserCardsController#reference_date` endpoint must not create a reference for a noncredit card, even when called directly. Other APIs, background jobs, imports, context cloning, and rollback must observe the same invariant. Never rely solely on hiding an option in the browser.

## Scope boundary and follow-on

V1 records spending, not a prepaid purse balance. Top-ups, reloads, refunds against stored value, and an authoritative remaining balance need their own convention in NARUTO-05 V2 or later. Debit bank balance deduction/reconciliation is deferred to NARUTO-06; do not double count a card purchase and a separately entered bank transaction meanwhile. Foreign currencies, multi-account debit routing, and Open Finance remain out of scope.

The NARUTO-06 contract must continue to call this a spending total until a separate top-up contract exists; it cannot infer remaining prepaid value from these purchases alone.

## Acceptance boundary

Call NARUTO-05 ready for manual testing only after every slice's focused specs, relevant feature specs, JS build, RuboCop, and CI checks pass, or any environment-only failure is explicitly recorded. Manual test credit regression, prepaid creation and editing, one-installment rejection, no references/invoice projections, dates/paid state, both screen sizes, context/index/report behavior, and rollback. Existing debit records should remain accessible. A local pass is not a claim about HMG or PROD.
