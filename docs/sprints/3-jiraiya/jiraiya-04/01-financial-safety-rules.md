# JIRAIYA-04 Planning: Financial Safety Rules

## Outcome Target

The financial domain should reject mutations that make paid history unreliable.

This slice is not about adding more convenience first.
It is about making the write model explicit and safe.

The main questions are:

- what can still be edited after payment happened?
- what should be blocked outright?
- what can be unlocked only with an explicit warning flow?
- what multi-record flows must stay structurally synchronized?

This should remain narrow and rule-driven.

## Scope

Primary records in scope:

- `CashTransaction`
- `CardTransaction`
- `CashInstallment`
- `CardInstallment`
- exchange-related records under `EntityTransaction` / `Exchange`
- `Reference` where invoice/payment history is affected

Secondary flows in scope:

- bulk payment flows
- destroy flows
- replay/apply flows from messages
- paid / not-paid synchronization flows from messages
- subscription-linked mutation flows when they touch paid history

Out of scope for the first pass:

- broad reporting redesign
- dashboard redesign
- full category-system redesign
- cosmetic UX work not required for warning/override flows

## Core Product Rule

Paid history is not normal editable form state.

Once a payment has happened, the app should treat that portion of the timeline as historical accounting data, not as a draft.

That means:

- past paid records should bias strongly toward immutability
- structural edits should usually be blocked
- if an override exists, it must be explicit and rare

## Initial Rule Matrix

### 1. Paid installment state

For any paid `CashInstallment` or paid `CardInstallment`:

- changing `price`: blocked
- changing `date`: blocked
- changing `month` / `year`: blocked
- deleting the installment: blocked
- reordering installment structure around it: blocked

Reason:

- these changes rewrite historical balance meaning
- they also risk breaking references, card-cycle state, and projections

### 2. Unpaid installments on a partially-paid transaction

If a transaction has at least one paid installment and at least one unpaid installment:

- editing unpaid installments is allowed in V1 only when the edited installment dates stay strictly after the latest paid installment date
- this includes:
  - changing future unpaid installment dates
  - changing future unpaid installment prices
  - changing future unpaid installment count / structure
  - rebuilding the future unpaid portion from scratch
- any edit that would place an unpaid installment on or before the latest paid installment date is blocked

Reason:

- the historical paid portion remains frozen
- the future unpaid portion can still be treated as a plan, as long as it stays entirely after the paid boundary

#### Catch-up entry warning case

There is one realistic delayed-entry workflow that should not be treated as a dead end:

- the user comes back after several days away from the app
- some transactions in that time range were already paid in real life
- other transactions in the same time range were never registered

Example paths:

- mark existing transactions as paid first, then create the missing transactions
- create the missing transactions first, then mark the existing ones as paid
- enter everything strictly in historical order

In the first two paths, a normal historical lock can be hit even though the user is not trying to falsify history.
The user is just catching up.

For V1 planning, this should be treated as a narrow warning/confirmation candidate:

- the app may warn that the operation crosses an already-settled boundary
- the user may explicitly confirm the catch-up ordering correction
- this bypass must stay limited to delayed-entry ordering conflicts, not broad financial rewrites

### 3. Whole-transaction edits after payment exists

For `CashTransaction` / `CardTransaction` with any paid installment:

- editing description/comment: allowed
- editing structural associations (`user_card`, `user_bank_account`, subscription binding): blocked by default
- editing total `price`: blocked
- editing anchor `date`: blocked if it rewrites paid installments
- changing category/entity allocation: blocked by default once the transaction is partially paid

Reason:

- metadata text can change without rewriting accounting history
- structural associations and totals can silently change projections and related flows
- parent-level category/entity allocation is too coarse to safely represent "from installment 3 onward" changes in V1

#### Narrow historical cycle correction

Some historical edits are operationally useful without changing the financial meaning of the record.

Examples:

- for a paid `CardTransaction`, the user is fixing the historical `date` but keeping the same `ref_month_year`
- the timestamp may become operationally absurd, such as `2000 BC`, and the app should still not care if the billing cycle is unchanged
- for a paid `CashTransaction`, the user is fixing a late-entry mistake around the month boundary, such as March versus April
- the user is fixing a typo in description/comment on a paid transaction

For V1 planning, these should be treated as a separate narrow correction class:

- for `CardTransaction`, historical date correction may be allowed as long as `ref_month_year` stays unchanged
- for `CashTransaction`, changing the effective month boundary may be allowed only through explicit warning + confirmation
- for `CashTransaction`, marking a normal paid cash installment back to `not paid` may be allowed only through explicit warning + confirmation when the installment is still in the current month
- description/comment typo correction remains normally allowed
- moving a paid card record into another `ref_month_year` remains blocked by default
- changing the effective cash month/year remains blocked by default unless the user explicitly confirms the catch-up correction path
- marking an older paid cash installment back to `not paid` remains blocked by default

This is not a broad override.
It is a constrained historical metadata correction path.

### 4. Destroy rules

For any transaction with paid history:

- destroy transaction: blocked
- destroy linked exchange or return flow: blocked

For transactions with no paid history:

- destroy may remain allowed, subject to existing dependency rules

### 5. Exchange and lend-return synchronization

When a transaction participates in exchange/lend-return flows:

- if paid history exists anywhere in the linked structure, structural mutation is blocked
- if no paid history exists, linked counterpart structures must still remain synchronized

#### Structural target for exchanges

The default exchange-return shape should be normalized to:

- one paying `EntityTransaction`
- many `Exchange` rows under that same `EntityTransaction`
- one single exchange-return `CashTransaction`
- many `CashInstallment` rows on that single `CashTransaction`

The installment rows should mimic the exchanges:

- one installment per exchange
- same number ordering
- same date / month / year
- same monetary amount

#### Canonical source-of-truth rule

`Exchange` rows and mirrored exchange-return `CashInstallment` rows must always remain structurally equivalent.

That means:

- exchange count must match mirrored installment count
- exchange dates must match mirrored installment dates
- exchange prices must match mirrored installment prices

For V1, `Exchange` is the canonical source of truth.

Therefore:

- structural edits on exchanges must update the mirrored cash installments
- direct structural edits on mirrored exchange-return cash installments must be blocked unless routed through the exchange side

This keeps the synchronization model one-directional in V1 and avoids bidirectional drift.

This replaces the current fan-out model where:

- one `EntityTransaction` with `exchanges_count = 3`
- creates three `Exchange` rows
- and each `Exchange` creates its own one-installment `CashTransaction`

The new default should instead be:

- one `EntityTransaction` with `exchanges_count = 3`
- three `Exchange` rows
- one exchange-return `CashTransaction`
- three `CashInstallment` rows on that one transaction

Why this is preferable:

- it is closer to the real financial intent: one return flow, many planned repayments
- recalculation becomes simpler because the return flow has one financial parent
- update and destroy rules become easier to reason about
- message replay and context cloning become cleaner because the exchange-return side has one stable record identity
- dashboards and detail pages can show one coherent return transaction instead of many fragmented clones

Examples:

- exchange count changes must not orphan returns
- reimbursement/borrow-return structure must not diverge from the active source shape without explicit regeneration

#### Cross-user paid-state rule

For exchange-return / borrow-return pairs shared between two users:

- the message layer is also part of the source of truth
- when user A marks the shared return flow as `paid`, user B's corresponding local return flow must also become `paid`
- when user A marks the shared return flow as `not paid`, user B's corresponding local return flow must also become `not paid`
- the same must work in the opposite direction from user B back to user A
- every such synchronization must emit a new assistant message explaining the remote paid-state change

This is not treated as a normal local-only installment toggle.

It is a synchronized cross-user state change on a shared obligation flow.

Implications:

- paid-state messages become part of the operational source of truth between the two users
- cross-user paid-state sync must preserve context/scenario isolation
- the paid toggle must resolve the corresponding local mirrored record before mutating it
- if the counterpart record cannot be resolved safely, the change must fail clearly instead of diverging silently

Current implementation status:

- implemented for direct pay / not-paid flows
- implemented for nested parent cash-transaction update flows
- implemented for derived contexts through matching `scenario_key`
- pure paid-state toggles are allowed on shared return flows even after paid history exists
- the carve-out applies only to `paid` state itself; structural/date/price/allocation rewrites remain blocked

### 6. Category assignment

Short-term rule:

- keep current category system, but restrict unsafe mixed category edits on protected records

V1 bias:

- block category/entity allocation changes on partially-paid records
- allow category cleanup only before paid history exists

This keeps the safety scope narrow while leaving room for a later allocation redesign.

## Warning / Override Policy

Do not add a general-purpose escape hatch.

V1 should distinguish only three states:

- `allowed`
- `blocked`
- `warn-only`

Warn-only is acceptable only when:

- the historical paid portion is unchanged
- the effect is local and understandable
- the override can be surfaced clearly in the UI

Likely V1 warn-only candidates:

- none by default for installment structure itself if the entire edited unpaid portion remains after the latest paid installment date
- paid `CardTransaction` date correction where `ref_month_year` stays unchanged
- cash month-boundary correction with explicit warning when the user needs to move a paid entry between adjacent effective periods
- delayed-entry catch-up ordering conflicts where the user is not changing the financial meaning, only reconciling the sequence of entry

Likely V1 non-candidates:

- changing total price after any installment is paid
- deleting a transaction with paid history
- moving an unpaid installment onto or before the latest paid installment date

For the narrow warning/confirmation candidates above, the UI should require:

- a clear warning that historical data is being touched
- explicit confirmation by the user
- traceable intent in the request path

## Context Interaction

All rules must apply inside `current_context`.

Contexts do not weaken financial safety.

That means:

- a derived context may diverge from `main`
- but paid history inside that derived context is still protected
- no context should be able to bypass immutability rules by accident

Message replay/apply flows must also respect these rules.

If an actionable message would require an unsafe rewrite of existing protected paid history, the apply path should fail clearly instead of silently mutating protected data.

Late entry is still allowed.

That means:

- creating a missing local transaction from an actionable message is allowed even if the date is already in the past
- marking that newly-created local record paid is also allowed if it does not rewrite protected existing local history

Blocked replay/apply cases are narrower:

- updating a local transaction in a way that rewrites already-paid installments
- destroying a local transaction with protected paid history
- restructuring an existing local paid flow in a way the safety rules forbid

Paid-state synchronization is a special case:

- a paid/not-paid message may update the counterpart local paid state when it is the mirrored shared return flow
- but it must not bypass the same structural-history protections
- the synchronization should change state, not silently rewrite protected pricing, dating, or installment structure

## Implementation Slices

### Slice 1. Rule Encoding

Add explicit rule predicates on the domain objects.

Examples:

- `has_paid_history?`
- `can_change_installment_structure?`
- `can_change_amount?`
- `can_destroy_safely?`

These should live in models/concerns or dedicated rule objects, not in controllers.

### Slice 2. Domain Write Guards

Enforce the rules in the write layer.

Expected hotspots:

- `CashTransaction`
- `CardTransaction`
- cash/card installment update paths
- exchange concerns
- bulk payment flows
- replay/apply controllers

Goal:

- impossible writes fail at the domain boundary

### Slice 3. Warning Flow

Add an explicit confirmation path for the small warn-only subset.

Requirements:

- visible warning text
- no silent acceptance
- controller path still delegates final decision to the domain rule

### Slice 4. Partial Payment Rules

Define partial `PayMultiple` only where allocation is unambiguous.

Safer first version:

- sequential partial payment
- exact residual application
- reject ambiguous split logic

### Slice 5. Exchange / Return Synchronization

Harden mutation rules around:

- exchange-linked cash flows
- reimbursement / borrow-return flows
- card-advance linked flows where historical consistency matters

This slice should also change the default exchange-return persistence model to the normalized shape above:

- many `Exchange`
- one return `CashTransaction`
- many `CashInstallment`

That means the implementation is not only validation work.
It also includes domain restructuring for exchange-return creation and update flows.

### Slice 6. Category Tightening

After core safety is stable:

- revisit ambiguous category stacking
- tighten unsafe edits on protected records

## Test Matrix

### Model / service specs

- changing paid installment amount is blocked
- changing paid installment date is blocked
- deleting paid installment is blocked
- changing transaction total after payment is blocked
- changing future unpaid dates on partially-paid transaction follows warn-only rule
- destroy with paid history is blocked
- exchange-linked mutation keeps structure in sync or is blocked
- one `EntityTransaction` with many exchanges produces one exchange-return `CashTransaction` with matching many `CashInstallment`
- updating exchange count updates the single return transaction instead of fanning out into many transaction rows
- deleting one exchange updates or removes the single return transaction correctly

### Request specs

- blocked mutation returns clear failure
- warn-only mutation requires explicit confirmation
- bulk payment partial succeeds only in allowed cases
- replay/apply cannot bypass the same safety rules

### Context-specific regression coverage

- blocked in `main_context`
- blocked in derived context too
- no cross-context side effects when a guarded mutation fails

## Recommended Build Order

1. encode rule predicates
2. block unsafe write paths in domain layer
3. add focused model/service specs
4. add request-level failure coverage
5. add warn-only confirmation flow
6. add partial `PayMultiple`
7. harden exchange/return synchronization
8. tighten category edits

## Success Criteria

`JIRAIYA-04` is done when:

- paid history can no longer be rewritten accidentally
- risky mutation paths fail clearly
- any allowed override is explicit
- replay/apply flows respect the same rules
- context-aware runtime does not weaken the safety model

## Non-Goals For This Slice

- replacing the whole category model
- rebuilding reports
- designing a large admin/audit interface
- optimizing every bulk workflow before rules are stable

The first job is correctness.
