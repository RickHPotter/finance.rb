# KAKASHI-16 Allocation Mutation Contract

## Objective

Allow safe category and entity corrections after payment and provide previewed bulk
allocation actions on cash transaction, card transaction, and budget indexes without
rewriting monetary history or damaging generated financial structures.

KAKASHI-16 is the shared allocation-mutation foundation required by KAKASHI-18. The
later merge feature may reuse its planners, eligibility results, locks, mutation
services, recalculation registry, audit grouping, and preview/apply contract.

## Locked Product Decisions

- Paid history does not by itself lock a category or entity correction.
- An allocation correction needs no extra confirmation when transaction price,
  installment prices, and every reference month/year remain unchanged.
- Description, comment, and date may change in the same save without confirmation when
  the persisted reference month/year remains unchanged.
- Existing paid-history rules continue to govern price, installment-price, installment
  structure, payment-state, and reference-period changes.
- Bulk Add Entity creates a neutral allocation: zero price, zero return, no exchanges,
  and non-payer state.
- Bulk Remove Entity accepts only a neutral allocation.
- Bulk Switch Entity accepts only a neutral source allocation and preserves no
  monetary or exchange-bearing meaning.
- Payer entities are never removable or switchable through the Bulk Action Bar.
- A payer entity may still be removed through the normal transaction form. The
  supported way to replace one is to remove the old nested allocation and add/configure
  the new one in the form, where the full domain workflow is visible.
- Strict all-selected application is the default.
- When independent rows are eligible and other rows conflict, partial application
  requires a separate explicit `Apply eligible only` choice.
- Partial application is unavailable when a conflict belongs to a linked structural
  group that cannot be separated safely.
- Cash/card installment rows selected in an index are deduplicated to their unique
  parent transactions before planning. Preview shows both selected-row and unique-record
  counts.

## Prerequisites and Dependency Direction

KAKASHI-16 builds on:

- KAKASHI-04 exchange correction/domain services
- KAKASHI-05 Piggy Bank invariants
- KAKASHI-08 V2 grouped auditing and allocation rollback adapters
- KAKASHI-14 category presentation
- KAKASHI-15 canonical Turbo navigation and index return state

KAKASHI-10 through KAKASHI-13 and KAKASHI-17 are not prerequisites. KAKASHI-12 may
later evolve friendship identity, but KAKASHI-16 uses the current `Entity#entity_user`
contract and keeps friendship checks behind an explicit policy boundary.

KAKASHI-18 depends on KAKASHI-16, not the reverse.

## Terminology

### Allocation owner

The record whose category/entity membership is being changed:

- `CashTransaction`
- `CardTransaction`
- `Budget`

Subscriptions, Investments, generated projections, and related counterpart records may
participate in eligibility or coordinated side effects, but they are not directly
selectable KAKASHI-16 bulk owners.

### Allocation row

- category transaction allocation: `CategoryTransaction`
- entity transaction allocation: `EntityTransaction`
- budget category allocation: `BudgetCategory`
- budget entity allocation: `BudgetEntity`

### Neutral entity allocation

An `EntityTransaction` is neutral only when all of the following are true:

- `is_payer` is false
- `price` is zero
- `price_to_be_returned` is zero
- it has no `Exchange` rows

`loan_return_percentage` does not turn a zero, non-payer row into a monetary
allocation, but normal creation defaults must remain valid and deterministic.

### Structural allocation

An allocation is structural when changing it may alter generated records, counterpart
identity, financial projections, or a model invariant. Examples include:

- built-in card payment, card installment, card advance, Investment, Subscription,
  Exchange/Return, Borrow Return, failed return, and Piggy Bank families
- a payer or exchange-bearing `EntityTransaction`
- friend-backed entity identity
- a Subscription-owned allocation
- the single entity shared by a Piggy Bank source and generated return
- an allocation on a generated cash projection

### Descriptive correction

A correction that changes categorization or a neutral entity label without changing
amount, return responsibility, generated structure, payment history, or reference
period.

## Current Repository Inventory

### Current paid-history boundary

`HasFinancialSafetyRules#can_change_allocation?` currently returns false after any paid
installment, except for the Subscription bypass. `HasFinancialSafetyGuards` then adds
`allocation_locked_after_payment` whenever submitted category/entity IDs differ.

KAKASHI-16 replaces this blanket predicate with an operation-aware allocation policy.
The paid-history guard still owns monetary/installment/reference safety; the allocation
policy owns category/entity eligibility.

### Current allocation owners

`CategoryTransaction` is polymorphic across:

- CashTransaction
- CardTransaction
- Investment
- Subscription

`EntityTransaction` is polymorphic across:

- CashTransaction
- CardTransaction
- Subscription

Budgets use the separate `BudgetCategory` and `BudgetEntity` joins.

The KAKASHI-16 Bulk Action Bar targets cash transactions, card transactions, and
budgets. The planner must still recognize Subscription/Investment/generated ownership
when determining whether a selected transaction can change safely.

### Current selection behavior

Cash/card index checkboxes select installment rows because existing bulk payment and
transfer actions operate on installments. Allocation actions operate on the parent
transaction instead:

- retain the existing checkbox
- submit its `bulk_record_id` for allocation actions
- deduplicate repeated installments of the same transaction
- preserve installment IDs for existing payment/transfer actions
- report selected rows and unique owners separately

Budgets are already selected as budget records and keep their separate selection kind.

### Current audit support

All four allocation-row models are financially audited and KAKASHI-08 V2 has rollback
adapters for them. One HTTP apply request already provides one root audit operation.
KAKASHI-16 must keep all coordinated writes inside that operation and add bounded
operation metadata for action, requested/eligible/affected/conflict counts, source, and
destination.

Preview is read-only and creates no committed audit operation.

## Safe Paid-History Write Envelope

The normal cash/card form may bypass the old allocation lock only when the complete
submitted change stays inside this envelope:

- category allocation changes approved by the allocation policy
- entity allocation changes approved by the form allocation policy
- optional description change
- optional comment change
- optional date change whose derived reference month/year is unchanged
- no transaction price change
- no installment price change
- no added, destroyed, or reordered installment
- no installment reference month/year change
- no user card, bank account, subscription link, reference link, or generated-type
  change hidden inside the same correction

For card transactions, date safety is determined from the persisted and proposed card
reference plus every installment month/year, not merely the calendar month of
`CardTransaction#date`.

For cash transactions, the parent and every installment must retain their persisted
reference month/year.

If any submitted field falls outside the envelope, the existing paid-history
confirmation or rejection path decides the result. An allocation change must never act
as a bypass for an otherwise unsafe historical rewrite.

No extra confirmation is shown merely because an accepted correction touches paid
history. KAKASHI-08 records the change.

## Form and Bulk Policy Separation

The same policy/planning namespace serves both entry points, but capabilities differ.

### Normal form

The form has full nested allocation context and may:

- add/remove/switch ordinary categories
- add/remove/configure entity allocations
- remove a payer entity
- replace a payer by removing the old nested row and adding/configuring a new row
- invoke existing domain coordination for exchanges, shared returns, subscriptions, or
  Piggy Banks

The form must submit enough nested information for model/domain validation. A direct
request receives the same checks as the visible form.

### Bulk Action Bar

Bulk actions intentionally support a smaller, deterministic contract:

- category add/remove/switch only when category-family policy approves
- entity add as neutral only
- entity remove/switch only for a neutral source row
- no payer, monetary, return-bearing, or exchange-bearing entity mutation
- no implicit redistribution of entity price
- no implicit creation/deletion of exchanges or friend messages

A bulk conflict points the user to the normal form when the richer workflow is
required.

## Category Operation Contract

### Add Category

- create the appropriate allocation join when absent
- treat an existing destination allocation as a no-op
- reject foreign-user, inactive, or policy-protected categories
- validate the resulting category family before apply

### Remove Category

- destroy the matching allocation when present
- treat an absent source allocation as a no-op
- do not remove a required structural category
- do not leave the owner in an invalid category-family state

### Switch Category

- add destination when absent
- remove source
- when source and destination are both present, remove only source and keep the existing
  destination row
- never create a duplicate join
- reject same source/destination as a no-op
- validate the final category set rather than validating two disconnected writes

### Built-in categories

Structural built-in categories do not appear as generic bulk source/destination choices
in V1. Their membership changes only through the owning domain workflow. Ordinary
custom categories remain eligible even when the transaction also contains a protected
built-in, provided the final family remains valid.

This protects generated semantics without turning every transaction containing a
built-in category into an automatic conflict.

## Entity Operation Contract

### Add Entity

- create an `EntityTransaction` only when the entity is absent
- initialize it with `price: 0`, `price_to_be_returned: 0`, `is_payer: false`, and no
  exchanges
- use deterministic valid defaults for status and loan-return percentage
- do not rebalance or divide the transaction price
- treat an existing destination allocation as a no-op

### Remove Entity

- bulk removal requires a neutral matching allocation
- a payer, non-zero, return-bearing, or exchange-bearing row is a conflict
- an absent source is a no-op
- the resulting transaction must still satisfy Piggy Bank and other entity-count
  invariants

### Switch Entity

- bulk switch requires a neutral source allocation
- change the neutral row to the destination entity when the destination is absent
- when destination already exists, remove the neutral source and retain the existing
  destination without changing its values
- never transfer payer responsibility, values, return percentages with monetary
  meaning, exchanges, or friend identity through the generic bulk path
- same source/destination is a no-op

### Built-in and friend-backed entities

The built-in self entity and user-backed friend entities are structural identity
boundaries for generic bulk mutation. They are not generic bulk destinations or
sources. Their changes use the normal form/domain path, which validates local and
counterpart behavior explicitly.

## Structural-Family Rules

The planner evaluates the final owner state and returns a localized reason code.

### Generated card/investment projections

Generic bulk allocation mutation must not rewrite generated Card Payment, Card
Installment, Card Advance, Investment aggregate, Exchange Return, or Piggy Bank Return
records. Their source workflow owns their allocation.

### Exchange and shared-return families

- built-in category membership is protected
- payer or exchange-bearing entities are form-only
- friend-backed identities are form/domain-only
- a neutral unrelated entity/category correction is eligible only when it does not
  change counterpart selection or projection rules
- linked source/counterpart/projection records form one structural group for planning

### Piggy Banks

- Piggy Bank/Piggy Bank Return category membership is protected
- a source and generated return must retain the required shared single entity
- bulk entity add/remove/switch that could violate the one-entity invariant conflicts
- the normal form may coordinate a supported entity replacement through the Piggy Bank
  domain service

### Subscriptions

Subscription-owned category/entity sets are changed through the Subscription workflow,
which synchronizes its linked transactions. A generic transaction bulk action must not
create an allocation that the next Subscription synchronization silently overwrites.
Selected Subscription-owned transactions therefore return a structural conflict when
the requested change overlaps inherited allocations.

### Budgets

Budget allocations are planning criteria rather than `CategoryTransaction` or
`EntityTransaction` rows:

- add/remove/switch uses `BudgetCategory`/`BudgetEntity`
- final validation requires at least one category or entity
- duplicate joins collapse idempotently
- the resulting inclusive/exclusive uniqueness rules must pass
- a conflict in one selected budget does not silently invalidate another

## Preview Contract

Every bulk action opens a server-planned preview before apply.

Preview includes:

- action and source/destination labels
- selected index-row count
- unique owner count
- eligible owner count
- affected owner count
- no-op/skipped count
- conflict count
- grouped localized reasons
- representative record links
- whether strict apply is available
- whether `Apply eligible only` is available

Planner outcomes:

- `eligible`: a mutation is required and safe
- `noop`: already satisfied, missing removable source, or source equals destination
- `conflict`: requested mutation is unsafe or invalid

`affected` means eligible rows that will actually change, not selected rows.

Preview must not mutate records, touch timestamps, recalculate data, or create an audit
operation.

## Apply and Concurrency Contract

Preview produces a short-lived signed token/digest bound to:

- actor
- current context
- owner type
- sorted unique owner IDs
- action
- source/destination IDs
- planner result fingerprint

Apply:

1. validates token ownership and expiry
2. reloads and locks selected owners and affected allocation rows
3. replans under lock
4. rejects stale preview when eligibility/fingerprint changed
5. applies all required writes in one database transaction
6. performs coordinated structural writes in the same audit operation
7. recalculates affected derived data
8. returns to the validated current index state

Strict apply is enabled only when there are no conflicts. No-ops do not prevent strict
apply.

When conflicts exist, the user may explicitly choose `Apply eligible only` only if the
planner marks every eligible owner independent from every conflict. The eligible subset
then applies atomically as one operation. It is not a record-by-record best-effort loop.

Linked exchanges, shared returns, subscriptions, Piggy Banks, and generated projection
groups cannot be split when one member conflicts.

## Recalculation Contract

### Transaction allocation correction

Because price, installment prices, paid state, and reference period remain unchanged:

- do not run the financial balance recalculation service
- refresh source/destination Category or Entity cached counts/totals
- recompute matching/consumption for budgets in affected installment periods
- synchronize only a projection/domain family explicitly changed by an approved
  structural form workflow

### Budget allocation correction

- recompute the selected budget's matching installments and remaining value
- validate inclusive/exclusive uniqueness after the proposed final allocation set
- run downstream balance recalculation only when the resulting persisted budget values
  are balance inputs that actually changed
- start any required recalculation at the earliest affected budget month

The recalculation registry consumes before/after impact collected by the planner so
callbacks are not relied on accidentally or run once per row.

## Audit and Rollback Contract

- one apply request creates one KAKASHI-08 root audit operation
- all allocation and coordinated projection writes join that operation
- operation metadata records action, owner type, source/destination, mode
  (`strict`/`eligible_only`), and bounded counts
- individual affected IDs remain discoverable from the operation's audit versions
- preview creates no operation
- a rejected/stale apply creates no committed financial versions
- rollback preview uses existing KAKASHI-08 allocation conflict detection
- successful rollback restores allocation rows and runs the same impact recalculation
- paid-history allocation corrections remain rollbackable subject to current-state
  conflicts

## Authorization and Context Isolation

- load cash/card/budget owners through `current_context`
- load categories/entities through `current_user`
- reject mixed owner types and foreign IDs server-side
- reject inactive source/destination records for new mutations
- never trust client eligibility flags, counts, prices, or neutral-state claims
- return not-found/controlled conflict without leaking another user's data
- preserve only KAKASHI-15-allowlisted index return state

## Failure Presentation

- preview conflicts are visible before confirmation
- apply-time validation/staleness errors keep the user on the preview/index workflow
- use stacked notifications: generic operation failure first, detailed localized
  reasons afterward
- Turbo responses replace affected rows/month fragments and allocation-dependent budget
  fragments without changing the canonical index URL
- non-Turbo apply follows Post/Redirect/Get to the same validated index state

## Explicitly Out of Scope

- changing transaction or installment amounts through bulk allocation actions
- changing reference month/year through bulk allocation actions
- implicit entity-price redistribution
- bulk creation/deletion of exchanges or friend messages
- bulk mutation of Investments or Subscriptions as directly selected owner types
- merging/deleting Category or Entity master records (KAKASHI-18)
- friendship redesign (KAKASHI-12)
- dashboard completion (KAKASHI-17)

