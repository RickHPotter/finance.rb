# JIRAIYA-04: Blocked Mutation Workarounds

## Purpose

`JIRAIYA-04` adds safety walls around paid history and exchange-linked structures.

Those walls should not leave the user with a dead end.

For every blocked mutation, this document defines the expected workaround path for V1.

This is not the same as a generic override mode.
Some cases should have:

- a normal workaround
- an explicit override path later
- or no bypass at all in V1

## Current Runtime State

The V1 warning flow is already implemented for the maintained request surfaces.

When a blocked historical mutation is attempted, the UI now shows:

- the specific lock reason
- the recommended workaround for that lock

This is warning/workaround support only.

There is still no generic unsafe override path.

The intended direction now is broader than the original V1 wording:

- every historical wall should try to reuse the same confirmation pattern
- but only when the mutation can still preserve financial, structural, and cross-user invariants
- the surface may differ by interaction type:
  - update flows confirm inside the rerendered form
  - destroy flows confirm through a notification action
- both still use the same two-step guarded confirmation model

## Classification

Each blocked case should map to one of:

- `workaround`: the user can solve it through a normal supported path
- `confirmation-required`: the mutation may proceed only after explicit warning + confirmation
- `override-later`: likely valid, but still needs a future explicit correction flow
- `hard-block`: should remain blocked in V1

## Workaround Matrix

### 1. Paid installment amount change

Blocked mutation:

- changing `price` on a paid `CashInstallment`
- changing `price` on a paid `CardInstallment`

Why blocked:

- it rewrites settled historical balance data

V1 workaround:

- create compensating transactions instead of editing history
- examples:
  - refund entry
  - adjustment entry
  - fee reversal
  - reimbursement entry

Classification:

- `confirmation-required` when the domain can preserve invariants
- `workaround` otherwise

Current direction:

- prefer explicit historical correction with confirmation when the domain can preserve invariants
- otherwise keep the mutation blocked and point to compensating entries

### 2. Paid installment date change

Blocked mutation:

- changing `date`, `month`, or `year` on a paid installment

Why blocked:

- it changes when the historical movement happened

V1 workaround:

- leave the historical record as-is
- create offsetting/corrective entries in the proper period if needed

Classification:

- `override-later`

Reason:

- compensating entries are sometimes acceptable
- but true date correction may still be needed in real accounting cleanup

Narrow V1 candidate:

- for paid `CardTransaction`, date correction may be allowed through warning + confirmation as long as `ref_month_year` stays unchanged
- for paid `CashTransaction`, changing the effective month/year should require explicit warning + confirmation when the user is correcting delayed entry around the month boundary
- for paid `CashTransaction`, marking the current-month paid record back to `not paid` may be allowed through warning + confirmation when the installment still belongs to the current month

### 3. Paid installment deletion

Blocked mutation:

- deleting a paid installment

Why blocked:

- it removes historical evidence of a settled movement

V1 workaround:

- do not delete
- create compensating reversal entries if the original payment was wrong

Classification:

- `hard-block`

### 4. Transaction total change after payment exists

Blocked mutation:

- changing parent `price` when any installment is already paid

Why blocked:

- it rewrites the meaning of both paid and unpaid portions

V1 workaround:

- if the future unpaid portion is wrong:
  - edit only the unpaid installment structure, as long as all edited dates stay strictly after the latest paid installment date
- if the paid portion was wrong:
  - use compensating entries

Classification:

- `workaround`

### 5. Unpaid installment moved onto or before latest paid date

Blocked mutation:

- editing unpaid installment dates so they cross the paid boundary

Why blocked:

- it mixes future planning with frozen history

V1 workaround:

- keep all edited unpaid installments strictly after the latest paid installment date
- if the real-world correction requires historical rewrite:
  - defer to explicit unsafe correction flow later

Classification:

- `override-later`

### 5a. Catch-up entry ordering collision

Blocked mutation:

- the user is catching up several days of activity
- existing transactions were already marked paid first
- creating or positioning missing transactions in that time range now collides with a historical boundary rule

Why blocked:

- the app sees a historical sequencing conflict, even though the user may only be reconstructing late-entered reality

V1 workaround:

- if practical, enter the missing transactions before marking the surrounding ones as paid
- otherwise, allow a narrow warning + confirmation flow for delayed-entry reconciliation

Classification:

- `override-later`

### 6. Destroying a transaction with paid history

Blocked mutation:

- destroying `CashTransaction` / `CardTransaction` with paid installments

Why blocked:

- it removes historical accounting structure

Current runtime:

- `CashTransaction`
  - first destroy attempt fails with the historical-lock warning
  - the warning may expose `Confirm historical change`
  - only the second explicit confirmed destroy may proceed
- `CardTransaction`
  - destroy is confirmation-required only when the affected billing cycles remain financially covered after removal
  - the coverage check must include already-settled `CARD PAYMENT` and `CARD ADVANCE` amounts in those cycles
  - if the remaining cycle debt would fall below the remaining settled amount, destroy stays blocked

Fallback workaround:

- if the destroy is still blocked after invariant checks:
  - do not destroy
  - neutralize through compensating entries
  - archive/hide at the UI level later if visual cleanup is needed

Classification:

- `confirmation-required` when the invariants survive the destroy
- `hard-block` otherwise

### 7. Changing category/entity allocation on a partially-paid transaction

Blocked mutation:

- editing parent-level category/entity allocation once the transaction is partially paid

Why blocked:

- the current model is too coarse to express different allocation across already-paid vs future installments safely

V1 workaround:

- if no installment is paid yet:
  - edit normally
- if partially paid:
  - keep the existing transaction unchanged
  - create a new future transaction for the new allocation plan if needed

Example:

- installments `1..2` stay on the original structure
- installments `3..6` move into a new future-only transaction with the new sharing rule

Classification:

- `workaround`

### 8. Structural edits on mirrored exchange-return cash installments

Blocked mutation:

- directly changing the count, dates, or prices of exchange-return `CashInstallment` rows when they mirror `Exchange`

Historical baseline:

- this began as a blocked one-way model while the normalized exchange-return shape was being introduced

Current runtime:

- if the mirrored `EXCHANGE RETURN` installments are still unpaid, structural edits are allowed
- the mirrored change must sync back to the canonical `Exchange` side
- and the counterpart user must receive a normal actionable assistant `update` message for the shared structure change
- if the change is only paid / not-paid state, this does not use the structural action-message path; it stays on the paid-state sync notification path

Classification:

- `workaround`
- if paid history is involved but the mutation is still coherent, prefer confirmation over a dead end

### 9. Exchange count/shape change after linked paid history exists

Blocked mutation:

- changing exchange structure when the linked return flow already contains paid history

Why blocked:

- it risks rewriting protected historical repayment structure

V1 workaround:

- stop mutating the old linked structure
- create a new forward-looking exchange arrangement if needed
- use compensating entries for the historical mismatch

Classification:

- `hard-block`

### 10. Replay/apply that would rewrite protected local paid history

Blocked mutation:

- applying an actionable message that would update/destroy a local record in a way that rewrites already-paid history

Why blocked:

- assistant flows must not bypass domain safety

V1 workaround:

- allow the message to remain unapplied
- show a clear failure reason
- let the user create a manual corrective local transaction instead

Important distinction:

- creating a missing local transaction dated in the past is still allowed
- rewriting protected existing paid history is what stays blocked

Classification:

- `workaround`

### 11. Deleting exchange-linked paid return structures

Blocked mutation:

- destroying return-side structures that already participated in paid exchange history

Why blocked:

- it breaks the financial trace of a linked obligation flow

### 12. Counterpart paid-state sync cannot be resolved safely

Blocked mutation:

- user A marks a shared exchange-return / borrow-return flow as `paid` or `not paid`
- but the app cannot resolve the mirrored local record for user B safely

Why blocked:

- the paid-state toggle is expected to stay synchronized between the two users
- if the counterpart record is ambiguous or missing, applying the toggle on only one side would create silent divergence

V1 workaround:

- leave the original state unchanged
- emit a clear failure message
- repair the shared linkage first, then retry the paid-state action

Classification:

- `hard-block`

Current implementation status:

- implemented
- the request layer now returns a clear failure instead of mutating only one side

### 11. Historical cycle or month-boundary correction

Blocked mutation:

- changing the historical date of an already-paid `CardTransaction` while keeping the same billing cycle
- changing the effective month/year of an already-paid `CashTransaction` during delayed-entry cleanup around the end/start of adjacent months

Why blocked:

- the current V1 runtime treats paid history conservatively and does not yet distinguish cycle-preserving corrections from broader historical rewrites

V1 workaround:

- for cards, allow the correction only if `ref_month_year` remains unchanged and the user confirms it
- for cash, allow the correction only through explicit warning + confirmation when the user is fixing a real delayed-entry month-boundary mistake
- otherwise, leave the record as-is or use a compensating path

Classification:

- `override-later`

V1 workaround:

- keep the structure
- neutralize with offsetting entries if needed

Classification:

- `hard-block`

## Override Candidates

These are the main blocked cases most likely to deserve explicit unsafe correction later:

- paid installment date correction
- unpaid installment crossing the latest paid boundary
- delayed-entry catch-up ordering collision
- historical card-cycle-preserving date correction
- historical cash month-boundary correction
- historical allocation correction
- historical exchange repair

If an override is introduced later, it should require:

- explicit confirmation
- visible unsafe wording
- required reason
- audit trail

## V2 Direction

The next iteration should not invent a different workaround UI for each eligible
historical mutation.

Instead:

- if a blocked mutation is promoted into an allowed historical correction path
- and that path is still considered explicit and safe enough to permit

then it should reuse the same confirmation shape already introduced in V1:

- first submit fails with the specific confirmation-required error
- the rerendered form explains the historical risk
- the form exposes the same `confirm_historical_change` action
- the second submit carries explicit confirmation and re-enters the same domain guard

This keeps the write model strict while making the exception paths predictable.
The user is still allowed to damage base history deliberately, but the app now makes
that choice explicit and harder to do accidentally.

This confirmation shape should now be treated as the preferred interaction for all domain-approved historical corrections, not only the original narrow examples.

## UX Expectation

For each blocked case, the app should eventually show:

1. what is blocked
2. why it is blocked
3. the recommended workaround
4. whether an explicit override exists

That keeps safety usable instead of merely restrictive.
