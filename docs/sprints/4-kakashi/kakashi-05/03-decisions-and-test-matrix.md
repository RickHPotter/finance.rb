# KAKASHI-05 Piggy Bank Transaction Flow: Decisions and Test Matrix

## Locked Product Decisions

These decisions were confirmed for V1 and are implementation constraints.

### D1. Which source transaction types support `PIGGY BANK`?

Decision: cash transactions only. Both `PIGGY BANK` and `PIGGY BANK RETURN` are
`CashTransaction` records. Card transactions reject both categories.

Reason: a piggy bank represents movement from a bank/cash account into an asset-like
destination. Card-origin support introduces debt-funded investment and invoice-cycle
semantics that do not fit the proposed single return date.

### D2. Is the return owned per source transaction or per selected entity?

Revised decision: each `PIGGY BANK` source has exactly one active entity and one
`PiggyBank` contribution link, but several sources may point to the same future
`PIGGY BANK RETURN`.

The entity is expected to represent a bank, but V1 does not validate the entity type.
The `PiggyBank` link belongs directly to its source and return cash transactions. The
return side is one-to-many: one return may aggregate several contribution links.

### D3. Where does the generated return deposit money?

Decision: copy the source cash transaction's `user_bank_account_id` to the generated
return and retain the app's current account validations.

V1 does not validate that the selected entity corresponds to that bank account. Such
a constraint requires broader changes to the bank, entity, and account models.

### D4. What happens to the existing `INVESTMENT` category?

Decision: existing `INVESTMENT` categories and rows are not automatically renamed,
classified, linked, audited, or migrated. A new explicit `/investments` workflow may
link supported valuation/profit records to a piggy-bank return group.

### D5. Can a piggy bank have partial or multiple returns?

Decision: there is exactly one `PIGGY BANK RETURN` `CashTransaction` per return group,
initially with one installment for the grouped principal and maturity date. Many source
contributions may point to it. The user may partially pay that installment through the
existing cash-installment payment flow.

Partial payment may split it into a paid installment and an unpaid remainder. The
piggy-bank projection must preserve that history and must not rebuild the return back
to a single installment. V1 does not interpret bank withdrawal restrictions or
recalculate the remaining amount for profit, penalties, or yield.

### D6. How is the generated return edited?

Revised decision: `PIGGY BANK RETURN#edit` needs a list sheet analogous to
`EXCHANGE RETURN`. It lists every contributing `PIGGY BANK` source and links to each
source editor. Group-level date, value, account, and valuation changes remain managed
from an authoritative grouped-return surface rather than independent source fields.

Reason: one authoritative editor prevents projection drift.

### D7. What happens when a source is duplicated?

Recommended default: create a fresh contribution with a new projected return; never
copy paid state. The duplicate form may explicitly attach it to another eligible return.

### D8. What sign rules apply?

Decision: enforce all of these rules in the model layer:

- source `PIGGY BANK` amount must be negative
- generated `PIGGY BANK RETURN` amount must be positive
- the UI default is `source price * -1`
- zero is invalid on both sides
- every return installment, including partial-payment splits, must remain positive

This makes initial principal and balance movement deterministic. Profit and loss may
change the return only through explicit signed `/investments` entries; fees, penalties,
and bank lockup rules are not inferred automatically.

### D9. Which grouped returns are eligible for attachment?

Decision: contributions may originate from any bank account, but an existing return is
selectable only when it uses the same bank entity as the new source. Selecting it keeps
the return's original date and renders that date disabled.

The group remains selectable until all linked source transactions and all return
installments are paid. Partial payment alone does not close the group.

### D10. How does `/investments` identify and value a piggy bank?

Decision: `/investments` uses a description-based searchable selector because one bank
may have many distinct piggy-bank groups. A linked investment entry is a signed delta:
positive means profit and negative means loss. Negative investment prices are allowed
only for this explicitly selected piggy-bank scenario.

## Backend Test Matrix

| Area | Scenario | Expected result |
| --- | --- | --- |
| Categories | `EXCHANGE` plus `PIGGY BANK` | rejected |
| Categories | `EXCHANGE RETURN` plus `PIGGY BANK RETURN` | rejected |
| Categories | `PIGGY BANK` plus `PIGGY BANK RETURN` | rejected |
| Categories | incompatible category marked `_destroy` | ignored by validator |
| Categories | forged `PIGGY BANK RETURN` on manual create | rejected or stripped |
| Create | valid source/entity/date/value | one source, link, return, and installment |
| Create | source selects eligible future return | source link attaches; grouped return principal increases |
| Create | contribution uses a different source account but the same bank entity | allowed |
| Create | contribution and selected return use different bank entities | rejected |
| Create | source selects paid, foreign-context, or incompatible return | rejected |
| Create | zero or multiple entities | rejected |
| Create | invalid generated return | entire save rolls back |
| Create | wrong source sign | rejected |
| Create | zero source price | rejected and fully rolled back |
| Create | zero or negative return price | rejected and fully rolled back |
| Update | change unpaid return date | return and installment dates synchronize |
| Update | change unpaid return value | return and installment values synchronize |
| Update | change source description | generated description synchronizes |
| Update | change source price after custom return | customized return is preserved |
| Update | remove the source entity | its contribution detaches; an empty unpaid return is removed |
| Update | remove category | all unpaid piggy-bank projections are removed atomically |
| Grouping | detach one of several unpaid sources | grouped principal decreases; return remains |
| Grouping | detach final unpaid source | empty grouped return is removed |
| Grouping | attach monthly sources | one return transaction and one initial installment remain |
| Grouping | attach to existing return | original date remains and submitted replacement date is ignored |
| Grouping | attach after partial return payment | paid rows remain; new principal increases unpaid remainder |
| Valuation | add `8` liquid profit to an `800` group | projected return and installment become `808` |
| Valuation | revise or remove profit before payment | grouped return recalculates from principal plus recognized profit |
| Valuation | record a negative linked investment | treated as loss; grouped unpaid return decreases |
| Valuation | negative ordinary investment without a piggy-bank selection | rejected |
| Valuation | loss makes grouped return or remainder non-positive | rejected atomically |
| Valuation | add delta after partial payment | paid rows remain; delta changes only the unpaid remainder |
| Payment | mark return installment paid | flow becomes finished |
| Payment | partially pay `10` from an initial `50` | paid installment `10`; unpaid remainder `40` |
| Payment | partial pay with zero/negative payment or remainder | rejected |
| Payment | save source after partial payment | split installments remain unchanged |
| Safety | edit paid return amount/date | blocked or confirmation required |
| Safety | destroy source with paid return | blocked by default |
| Isolation | link return from another user | rejected |
| Isolation | link return from another context | rejected |
| Duplication | duplicate source | new return; no reused IDs or paid state |
| Concurrency | repeat save/retry | no duplicate return or installment |
| Deletion | direct return deletion | blocked or coordinated through source |
| Legacy | any existing `INVESTMENT` row | unchanged |

## Request/UI Test Matrix

| Area | Scenario | Expected result |
| --- | --- | --- |
| Sheet mode | no piggy-bank category | current exchange entity sheet |
| Sheet mode | add `PIGGY BANK` | compact return date/value sheet |
| Sheet mode | remove `PIGGY BANK` | exchange sheet restored; stale nested input inactive |
| Defaults | open new piggy-bank sheet | opposite-sign transaction price populated |
| Defaults | user customizes return, then changes source price | custom value preserved |
| Date | desktop entry | shared datetime control persists correct zone/date |
| Date | mobile calendar/clock swap | real control and skeleton remain aligned |
| Validation | forged mixed-category payload | server returns stacked detailed notifications |
| Navigation | source detail | linked return, paid amount, and remaining amount visible |
| Navigation | generated return detail | source link visible; direct unsafe edit unavailable |
| Navigation | grouped return edit | list sheet shows every contributing source |
| Sheet mode | eligible future returns exist | user may create a return or attach to an existing one |
| Sheet mode | existing return selected | date is visible, disabled, and unchanged |
| Sheet mode | returns from another bank entity | excluded from selectable options |
| Investments | select piggy-bank return group | valuation is attributed to that group and updates its projected return |
| Investments | several groups share a bank | description-based search distinguishes them |
| Account | change source account before return payment | generated return inherits the updated account |
| Regression | create/update normal exchange | schedule and return projection unchanged |
| Regression | duplicate normal transaction | current behavior unchanged |

## Open Product Decisions

There are no remaining blocking product decisions for grouped returns and signed
profit/loss deltas. A dedicated piggy-bank identity may still be considered later, but
description-based selection is the chosen contract for this implementation.
