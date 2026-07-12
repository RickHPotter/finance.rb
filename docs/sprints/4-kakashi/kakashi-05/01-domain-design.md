# KAKASHI-05 Piggy Bank Transaction Flow: Domain Design

## Goal

Add an explicit, linked cash-flow pair for new piggy-bank operations:

- `PIGGY BANK` represents money leaving an account and entering a savings or
  investment destination.
- `PIGGY BANK RETURN` represents the initially expected principal returning.

Both sides are `CashTransaction` records. They must remain connected so the app can explain, update, and close
the full flow without relying on matching descriptions, values, or dates.

Existing `INVESTMENT` categories, transactions, and aggregate `Investment` model
projections are outside this feature and remain unchanged.

The user-facing names are:

| Internal category | English | Portuguese |
| --- | --- | --- |
| `PIGGY BANK` | Piggy Bank | Cofrinho |
| `PIGGY BANK RETURN` | Piggy Bank Return | Retorno do Cofrinho |

## Current Baseline

The existing exchange flow is implemented through more than the two categories:

1. A cash or card transaction owns one or more `EntityTransaction` records.
2. An `EntityTransaction` owns one or more `Exchange` rows.
3. Each monetary `Exchange` projects into an `EXCHANGE RETURN` `CashTransaction`.
4. Standalone exchanges mirror rows into cash installments; card-bound exchanges can
   aggregate into invoice-cycle projections.
5. Paid-history guards, cross-user messages, counterpart references, and audit tools
   protect and repair those projections.
6. The entity sheet edits allocation, return amount, return count, return schedule,
   and card-bound behavior.

Relevant existing code includes:

- `app/models/concerns/exchange_cash_transactable.rb`
- `app/models/concerns/has_exchanges.rb`
- `app/models/exchange.rb`
- `app/models/entity_transaction.rb`
- `app/views/entity_transactions/fields_sheet.rb`
- `app/javascript/controllers/entity_transaction_controller.js`
- `app/javascript/controllers/reactive_form_controller.js`

Piggy bank resembles exchange at the projection boundary, but it is not an exchange:
each return group has one expected return transaction, has no predefined multi-installment
schedule, no card-bound projection, no loan/reimbursement intent, and no cross-user
counterpart. Its installment structure may later evolve through normal partial-pay
behavior.

## Recommended Domain Model

Introduce a dedicated `PiggyBank` model as the contribution link between a source
`CashTransaction` and a generated or selected future return `CashTransaction`.
Several `PiggyBank` contribution links may point to the same return transaction.

Suggested columns:

| Column | Purpose |
| --- | --- |
| `source_cash_transaction_id` | Identifies the `PIGGY BANK` cash transaction |
| `return_cash_transaction_id` | Identifies the generated `PIGGY BANK RETURN` cash transaction |
| `return_date` | Expected or actual return date |
| `return_price` | Expected or actual returned amount, in cents |
| timestamps | Auditability |

Suggested constraints:

- unique index on `source_cash_transaction_id`
- non-unique index on `return_cash_transaction_id`, because monthly contributions may
  settle through one future withdrawal
- foreign keys for both associations
- `return_date` and `return_price` are required
- the source transaction price must be strictly negative
- `return_price` and the generated return transaction price must be strictly positive
- every generated or split return installment must remain strictly positive
- every source sharing a return must belong to the same user and context as that return
- the linked return must be a `CashTransaction` categorized as
  `PIGGY BANK RETURN`
- the source must have exactly one active entity allocation

The single source entity represents the bank or destination institution. V1 does not
validate that the entity is a bank and does not validate a relationship between the
entity and `user_bank_account_id`.

Do not reuse these fields for the new behavior:

- `EntityTransaction#price_to_be_returned`: it currently controls payer state and
  exchange creation semantics.
- `Exchange`: its callbacks and fields encode multi-row schedules, monetary versus
  non-monetary settlement, paid projection rebuilds, and card-bound aggregation.
- `CashTransaction#reference_transactable`: it is useful for canonical chains and
  cross-user shared returns, but it does not model contribution ownership or valuation.

For a grouped return, `reference_transactable` cannot be the authoritative source link
because there may be several sources. `PiggyBank` remains the authoritative join and
the return detail/edit surfaces list every contributing source.

## Grouped Contributions

A user may add money to the same piggy bank monthly and withdraw the complete balance
in one operation. For example, sources of `-800`, `-500`, and `-300` may all point to
one future `PIGGY BANK RETURN` rather than creating three unrelated returns.

When configuring a source, the compact entity sheet must offer two paths:

1. create a new future return using the entered date and projected value
2. attach the contribution to an eligible open return group

An eligible return must be system-managed, in the same user and context, and use the
same bank entity as the new contribution. Contributions may originate from any user
bank account. The grouped return's destination account remains authoritative and does
not need to match the source accounts.

When attaching to an existing return, its maturity date is shown but disabled. The
existing return date remains unchanged. Attaching a source increases the grouped
return principal by that source's projected contribution. Detaching a source reduces
it without deleting the return while other sources remain.

The return selector remains available until all contributing `PIGGY BANK` source
transactions and all `PIGGY BANK RETURN` installments are paid. A partially paid group
may therefore receive later contributions. Recalculation must preserve paid history
and apply new principal or profit/loss only to the remaining unpaid projection.

The grouped return still begins with one installment. Grouping contributions does not
create one installment per source. Partial payment may later split that single return
installment under the existing payment-history rules.

## Investment Valuation Integration

The `/investments` workflow should later allow an investment valuation or liquid-profit
entry to target a specific piggy-bank return group. This provides attribution even when
several contributions are withdrawn together.

Example:

1. create a `PIGGY BANK` source of `-800`
2. create its `PIGGY BANK RETURN` of `800`, due three months later
3. one month later, record `8` of liquid profit in `/investments` against that group
4. update the projected return cash transaction from `800` to `808`

Additional daily, monthly, or ad hoc valuation entries may update the same group. Each
entry is a signed delta: a positive price records profit and a negative price records
loss. Negative `Investment#price` is allowed only when the investment is explicitly
linked to a piggy-bank return group. For example, an early withdrawal may forfeit
profit that was recorded previously.

The return amount should be derived from grouped principal plus the current recognized
liquid profit, rather than losing attribution in an amalgamated withdrawal. Existing
legacy `INVESTMENT` rows remain untouched unless the user explicitly links a new or
supported investment record to a piggy-bank return.

## Lifecycle Contract

### Create

1. The user selects `PIGGY BANK` on a cash transaction.
2. The user adds exactly one entity and opens its sheet.
3. The sheet switches to piggy-bank mode and asks only for:
   - return date
   - return price
4. Return price defaults to `source transaction price * -1`.
5. The user either selects an eligible future return or chooses to create one.
6. Saving the source transaction atomically creates:
   - the source transaction
   - its `EntityTransaction`
   - its `PiggyBank` link
   - a new `CashTransaction` with `PIGGY BANK RETURN` and one initial installment, or
     an updated link to the selected grouped return

The generated return copies the source description, user, context, selected entity,
and `user_bank_account_id`. V1 adds no new validation between the chosen entity and
bank account; existing `CashTransaction` account validations remain authoritative.

The sign rules are hard model invariants. The UI may guide the sign, but saves must be
rejected when a source is zero or positive, or when a return is zero or negative.
Source/link/return creation must roll back atomically on any sign violation.

### Update

- Before any payment, editing a grouped return updates its single projected transaction
  and initial installment atomically for every linked contribution.
- Editing the generated return opens an authoritative grouped-return editor with a
  list sheet of all contributing sources. Source-specific edits still open the chosen
  source transaction; independent copies of group fields would allow drift.
- Changing the source transaction price does not silently overwrite a return price
  the user has already customized. It may refresh the default only while the nested
  piggy-bank record is new or still equal to the previous default.
- Removing `PIGGY BANK` removes that contribution link and reduces the grouped
  principal. The unpaid return is destroyed only when no contributions remain.
- Replacing or removing the only entity updates or removes the unpaid piggy-bank flow.

### Completion

- The generated return uses normal cash-installment payment behavior.
- A partial payment uses the existing installment split behavior. For example, an
  initial return installment of `50` due in three months can be partially paid as
  `10` after one month, producing a paid installment 1 of `10` and an unpaid
  installment 2 of `40` that retains the original maturity date.
- The piggy-bank flow remains pending while any return installment is unpaid
  and becomes finished when all return installments are paid.
- Once partial payment creates paid history, piggy-bank projection callbacks must not
  collapse the installments back into one row or overwrite the unpaid remainder.
- Partial payment must reject zero, negative, overpayment, or any split that would
  leave a zero or negative remainder.
- The app does not infer profit, loss, yield, penalties, or lockup behavior. Only
  explicit valuation/profit entries from `/investments` may revise the projected
  maturity value.

### Paid History

- Once any generated return installment is paid, changing category allocation,
  entity ownership, return date, return amount, or deleting either side must use the
  existing financial-history confirmation/locking conventions.
- Destruction of a source with a paid return should be blocked by default.
- An explicit confirmed correction must update both sides atomically and preserve a
  traceable reference chain.
- Piggy-bank behavior should integrate with `HasFinancialSafetyGuards` through a
  small shared projection contract instead of adding category-name conditionals
  throughout that concern.

## Category Rules

The model layer must reject invalid combinations even if the UI prevents them.

Define two mutually exclusive category families:

- exchange family: `EXCHANGE`, `EXCHANGE RETURN`
- piggy-bank family: `PIGGY BANK`, `PIGGY BANK RETURN`

Rules:

1. A transaction cannot contain categories from both families.
2. `PIGGY BANK` and `PIGGY BANK RETURN` cannot coexist on one transaction.
3. `EXCHANGE` and `EXCHANGE RETURN` should also be explicitly prevented from
   coexisting on one transaction if that is not already enforced.
4. A user-created source may select `PIGGY BANK`; `PIGGY BANK RETURN` is system-owned
   and should not appear as a normal selectable category.
5. Generated returns cannot acquire exchange-family categories through update,
   duplication, bulk transfer, or subscription flows.

Implement the mixed-family rules on cash transactions. Card transactions must reject
both piggy-bank categories entirely.
Do not rely on Stimulus option hiding as the correctness boundary.

## UI Contract

The existing entity chip remains the entry point.

When `PIGGY BANK` is absent:

- open the current entity sheet unchanged
- retain price, price-to-be-returned, loan percentage, exchange count, schedule, and
  card-bound controls

When `PIGGY BANK` is present:

- open a piggy-bank-specific sheet body
- let the user create a new return or select an eligible open return group
- show the selected entity, return date, and return price
- initialize return price from the transaction price with the opposite sign
- when attaching, filter returns by the selected bank entity and disable the inherited
  return date
- use `Views::Shared::DatetimeInput` for the return date
- hide all exchange-specific controls and nested exchange rows
- preserve entered piggy-bank values when the user temporarily closes the sheet
- clear or mark piggy-bank nested data for destruction if the category is removed

The mode must be determined from submitted nested category state, including `_destroy`,
not from visible chip text. The server remains authoritative when JavaScript is absent
or stale.

## Scope Boundaries

V1 includes:

- linked contribution and grouped-return cash flows
- one expected return transaction per group, with one or more source contributions
- one initial return installment that may split through partial payment
- exactly one source entity, without bank-type validation
- editable grouped return date and amount before payment
- a grouped-return edit list sheet showing every contributing source
- explicit `/investments` valuation/profit attribution to a return group
- normal partial-pay support on the generated return
- category-family validation
- strict source-negative and return-positive validation
- source/return navigation and protected lifecycle

V1 excludes:

- recurring contributions
- compounding/yield calculations
- automatic profit, loss, penalty, or lockup calculations outside explicit
  `/investments` valuation entries
- live portfolio valuation
- brokerage/provider synchronization
- tax accounting
- cross-user notifications
- exchange audit and message machinery
