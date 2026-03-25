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

Likely V1 non-candidates:

- changing total price after any installment is paid
- deleting a transaction with paid history
- moving an unpaid installment onto or before the latest paid installment date

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
