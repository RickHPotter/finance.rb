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

## Classification

Each blocked case should map to one of:

- `workaround`: the user can solve it through a normal supported path
- `override-later`: likely valid, but requires explicit unsafe correction flow
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

- `workaround`

Future override:

- allow explicit historical correction with confirmation + reason

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

### 6. Destroying a transaction with paid history

Blocked mutation:

- destroying `CashTransaction` / `CardTransaction` with paid installments

Why blocked:

- it removes historical accounting structure

V1 workaround:

- do not destroy
- neutralize through compensating entries
- archive/hide at the UI level later if visual cleanup is needed

Classification:

- `hard-block`

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

Why blocked:

- in V1, `Exchange` is the canonical side
- direct installment editing would create bidirectional drift

V1 workaround:

- edit the `Exchange` rows instead
- let the mirrored return-side installments rebuild/sync from that source

Classification:

- `workaround`

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

V1 workaround:

- keep the structure
- neutralize with offsetting entries if needed

Classification:

- `hard-block`

## Override Candidates

These are the main blocked cases most likely to deserve explicit unsafe correction later:

- paid installment date correction
- unpaid installment crossing the latest paid boundary
- historical allocation correction
- historical exchange repair

If an override is introduced later, it should require:

- explicit confirmation
- visible unsafe wording
- required reason
- audit trail

## UX Expectation

For each blocked case, the app should eventually show:

1. what is blocked
2. why it is blocked
3. the recommended workaround
4. whether an explicit override exists

That keeps safety usable instead of merely restrictive.
