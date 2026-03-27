# JIRAIYA-04: Mirror Exchange Flow Spec Blueprint

## Purpose

This file is not implementation planning.
It is a spec-design contract for the shared return / mirror exchange flow between two
entity-linked users.

The goal is to create focused specs for the parts of `JIRAIYA-04` that are easiest to
think are working while still drifting in subtle ways:

- bidirectional paid-state synchronization
- assistant paid-state notifications
- shared return counterpart resolution
- reimbursement isolation from the source-side transaction

This file should be used to drive request/spec setup and assertions.

## Current Status

This blueprint has now been partially implemented in request coverage.

What is covered:

- card-origin shared return paid-state sync
- reimbursement-origin shared return paid-state sync
- reverse-direction sync from the counterpart `BORROW RETURN` side
- assistant `notification:paid_state` creation
- scenario-aware assistant routing
- counterpart-missing failure behavior
- reimbursement isolation:
  - the source reimbursement `EXCHANGE` transaction must stay untouched
  - only the shared return pair should mirror paid state

What the manual pass exposed and the specs now guard against:

- misrouting paid state into the source reimbursement transaction instead of the
  counterpart shared return
- duplicate-family counterpart ambiguity when multiple shared returns have the same
  installment signature
- bulk pay message deduplication collapsing distinct mirrored transactions into one

## Shared Vocabulary

Use named records in specs instead of hardcoded ids.

Recommended names:

- `user_a`
- `user_b`
- `user_a_entity_for_b`
- `user_b_entity_for_a`
- `origin_card_transaction`
- `origin_cash_transaction`
- `user_a_shared_return`
- `user_b_shared_return`
- `assistant_conversation`

## Required Setup Contract

Every spec built from this file must make the counterpart linkage explicit.

That means the test setup must create all of the following deliberately:

- `user_a` and `user_b`
- reciprocal user-backed entities
- the canonical source-side transaction
- the mirrored/shared return transaction for the source-side user
- the counterpart shared return / borrow-return transaction for the other user
- the assistant conversation in the correct scenario

The setup must not rely on accidental resolution through unrelated seed-like data.

### Counterpart Resolution Requirement

The spec setup must ensure that the app can resolve the counterpart through one of the
real supported paths, not through coincidence.

Preferred setup:

- direct reverse `reference_transactable` linkage where appropriate
- or a structurally matched counterpart pair that mirrors the real normalized shape

Do not leave counterpart discovery ambiguous.

If a spec wants to cover the failure path, that should be a separate context with
intentionally missing linkage.

## Context Scope

Each core use case should exist in two variants where relevant:

- `main_context`
- derived shared scenario context using the same `scenario_key` for both users

If a spec only covers `main_context`, that should be explicit.
If the behavior is expected to be scenario-aware, the derived-context version should be
written too.

## Canonical Shape Reminder

The normalized shape in current `JIRAIYA-04` terms is:

- canonical side:
  - one `CardTransaction` or `CashTransaction`
  - one paying `EntityTransaction`
  - many `Exchange`
- mirrored side:
  - one shared return `CashTransaction`
  - many mirrored `CashInstallment`

The important rule is:

- `Exchange` is canonical for structure
- the return-side `CashInstallment` rows mirror that structure
- paid / not-paid state synchronizes between the two users on the shared return pair

## Context 1

### Card-origin shared return

Setup:

- `user_a` has an existing `EXCHANGE` `CardTransaction`
- that source transaction has the normalized mirrored return flow on `user_a`:
  - `user_a_shared_return` with many installments
- `user_b` has the counterpart `BORROW RETURN` `CashTransaction`:
  - `user_b_shared_return`

### Use Case 1

Action:

- `user_a` marks installment `1` of `user_a_shared_return` as paid

Expect:

- installment `1` of `user_b_shared_return` also becomes paid
- no unrelated installments change
- `user_b` receives one new assistant `notification:paid_state` message
- that message is pending/acknowledgeable
- the message belongs to the correct assistant conversation and scenario

### Use Case 2

Action:

- `user_a` marks installments `1` and `2` of `user_a_shared_return` as paid

Expect:

- installments `1` and `2` of `user_b_shared_return` also become paid
- `user_b` receives two assistant `notification:paid_state` messages
- each message remains pending until acknowledged

### Use Case 3

Action:

- `user_b` marks installment `1` of `user_b_shared_return` as paid

Expect:

- installment `1` of `user_a_shared_return` also becomes paid
- `user_a` receives one new assistant `notification:paid_state` message
- the message is pending/acknowledgeable

### Use Case 4

Action:

- `user_b` marks installments `1` and `2` of `user_b_shared_return` as paid

Expect:

- installments `1` and `2` of `user_a_shared_return` also become paid
- `user_a` receives two assistant `notification:paid_state` messages

### Reverse Toggle Variant

The same context should also cover `not paid` reversal on already-paid shared return
installments.

Expect:

- the counterpart mirrored installment goes back to `not paid`
- assistant `notification:paid_state` still records the reverse change
- the synchronization remains scenario-scoped

## Context 2

### Cash-origin reimbursement shared return

Setup:

- `user_a` has an existing `EXCHANGE` `CashTransaction`
- that cash exchange was created with `intent: reimbursement`
- it generated:
  - `user_a_shared_return`
- `user_b` has the counterpart `BORROW RETURN` transaction:
  - `user_b_shared_return`

Important invariant:

- the source-side reimbursement transaction is not the paid-state target
- the shared return pair is the paid-state target

### Use Case 1

Action:

- `user_a` marks installment `1` of `user_a_shared_return` as paid

Expect:

- installment `1` of `user_b_shared_return` also becomes paid
- `user_b` receives one assistant `notification:paid_state` message
- the original source-side reimbursement transaction keeps its own paid state unchanged

### Use Case 2

Action:

- `user_a` marks installments `1` and `2` of `user_a_shared_return` as paid

Expect:

- installments `1` and `2` of `user_b_shared_return` also become paid
- `user_b` receives two assistant `notification:paid_state` messages
- the original reimbursement source transaction still does not change paid state as a side effect

### Use Case 3

Action:

- `user_b` marks installment `1` of `user_b_shared_return` as paid

Expect:

- installment `1` of `user_a_shared_return` also becomes paid
- `user_a` receives one assistant `notification:paid_state` message
- the original source-side reimbursement transaction remains unchanged

### Use Case 4

Action:

- `user_b` marks installments `1` and `2` of `user_b_shared_return` as paid

Expect:

- installments `1` and `2` of `user_a_shared_return` also become paid
- `user_a` receives two assistant `notification:paid_state` messages
- the original reimbursement source transaction remains unchanged

### Reverse Toggle Variant

Also cover `not paid` reversal for the same reimbursement-backed shared return pair.

Expect:

- reverse synchronization still affects only the shared return pair
- the source reimbursement transaction still remains untouched

## Message Assertions

Every paid-state spec should assert the message shape, not only the installment state.

At minimum:

- message belongs to assistant conversation
- message belongs to the correct scenario
- message action is `paid_state`
- message remains pending until acknowledged
- acknowledging it removes it from the pending assistant view

If the test is not about acknowledgment, it should still assert that the message is
created in pending state.

## Non-Goals For These Specs

These contexts should not try to cover everything at once.

Do not overload these specs with:

- structural mirrored installment edits
- generic message replay/create/update flows
- unrelated historical-lock overrides
- conversation UI rendering details

Those belong in other focused spec groups.

## Recommended Spec Placement

Primary layers:

- `spec/requests/cash_installments_spec.rb`
  - paid / not-paid synchronization behavior
  - assistant message creation and pending state
- `spec/models/cash_transaction_spec.rb`
  - counterpart resolution invariants if needed
- `spec/requests/conversations_spec.rb`
  - only if acknowledgment/pending filtering needs an extra end-to-end assertion

## Expected Current Outcome

This document exists because the current runtime is expected to fail some of these
cases.

That is acceptable.
The point is to encode the intended behavior before continuing to patch around it.
