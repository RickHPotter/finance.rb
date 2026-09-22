# NARUTO-04 — Subscription Enhancements: Product and Data Contract

## Status

Planning — 2026-09-21. Not yet started.

---

## Goal

Extend the existing `Subscription` (`finance_subscriptions`) model with three
improvements:

1. **Salary-as-subscription** — allow a recurring income (salary, freelance retainer,
   rental income) to be modelled as a subscription with `subscription_kind: "income"`.
2. **Bulk edit** — select multiple subscriptions and change their status or category in one action.
3. **Rollback audit verification** — confirm that the existing `Audit::Rollback::Adapters::Subscription`
   covers all mutation paths correctly and add any missing specs.

---

## Non-Goals

- Automatic transaction generation on a schedule
- Payment method routing rules per subscription
- Start/end date enforcement
- Proration or partial-period calculation
- Salary split across multiple bank accounts (multi-destination deferred)

---

## Current State

### Subscription model (`finance_subscriptions`)

| Column | Type | Notes |
|---|---|---|
| `id` | bigint | PK |
| `user_id` | bigint | owner |
| `context_id` | bigint | required |
| `description` | varchar | required |
| `price` | integer (cents) | auto-updated from linked tx |
| `comment` | text | optional |
| `status` | varchar | `active`, `paused`, `finished` |
| `cash_transactions_count` | integer | counter cache |
| `card_transactions_count` | integer | counter cache |

The model already has `FinancialAuditable` and `Audit::Rollback::Adapters::Subscription`
exists. `CategoryTransactable` and `EntityTransactable` are included.

---

## Feature 1 — Salary as Subscription

### Motivation

Salary, rental income, and freelance retainers are recurring incomes. Currently a user
creates a subscription and manually adds cash transactions with a positive income amount.
There is no signal that distinguishes an expense subscription from an income subscription,
so they appear identically in lists and reports.

### Data model change

Add a `subscription_kind` string-backed enum column:

```sql
ALTER TABLE finance_subscriptions
  ADD COLUMN subscription_kind varchar NOT NULL DEFAULT 'expense';
```

Values: `expense` (default, existing behaviour), `income`.

### Behaviour changes

| Behaviour | `expense` | `income` |
|---|---|---|
| Default transaction direction | Negative (outgoing) | Positive (incoming) |
| Reports / monthly analysis | Outgoing | Incoming |
| UI badge colour | Existing (red-ish) | Green-ish |
| Can link card transactions? | Yes | Yes (salary advance via card is unusual but valid) |

### Built-in category suggestion

When `subscription_kind: "income"` and the user has a "SALARY" built-in category,
suggest it as the default category on the subscription form. Not enforced.

---

## Feature 2 — Bulk Edit

### Scope

Select N subscriptions from the index list and apply one of:
- Change `status` (e.g., pause all, finish all)
- Change `category` (assign all to the same category)
- Change `entity` (assign all to the same entity)

### UI pattern

Checkbox column on the subscription index. A floating action bar appears when one or
more subscriptions are selected, with the available bulk actions.

### Implementation

- `SubscriptionsController#bulk_update` action.
- `params[:subscription_ids]`, `params[:field]`, `params[:value]`.
- Wrapped in a single `AuditOperation` with `operation_kind: "subscription_bulk_edit"`.
- Each affected subscription generates its own `AuditVersion` under the shared operation.
- Turbo response: re-render affected rows via `turbo_stream.replace`.

### Rollback

The existing `Audit::Rollback::Adapters::Subscription` handles individual subscription
rollback. The bulk edit audit operation can be rolled back record-by-record using the
existing adapter, triggered by the rollback UI on the shared operation.

---

## Feature 3 — Rollback Audit Verification

### Current state

`Audit::Rollback::Adapters::Subscription` exists. Its coverage must be confirmed
against:

- Create (new subscription): rollback removes the subscription and its
  `category_transactions` / `entity_transactions`.
- Update (description, status, price, comment): rollback restores all changed fields.
- Destroy: rollback recreates the subscription (only possible if `can_be_destroyed?`
  was true at the time, meaning no linked transactions).
- Bulk edit (new in this sprint): rollback via the individual adapter called per record.
- Salary kind assignment (new in this sprint): rollback via update adapter.

### Deliverable

A spec file `spec/services/audit/rollback/adapters/subscription_spec.rb` covering all
paths listed above, plus any gaps found in the existing adapter implementation.

---

## Implementation Slices

### Slice 1 — subscription_kind column and enum
- Migration: add `subscription_kind varchar DEFAULT 'expense'`.
- Model: `enum :subscription_kind, { expense: "expense", income: "income" }`.
- Form: radio or toggle for kind on create / edit.
- Reports: update income/expense classification for subscriptions.
- Specs: model, request.

### Slice 2 — Bulk edit
- Checkbox UI on subscription index.
- `bulk_update` controller action.
- Audit operation wrapping.
- Turbo response.
- Request spec.

### Slice 3 — Rollback audit verification
- Audit all existing mutation paths.
- Add missing rollback adapter coverage.
- Spec file: `spec/services/audit/rollback/adapters/subscription_spec.rb`.

---

## Open Questions

1. **Price direction for income subscriptions** — should the `price` column be stored
   as a positive integer regardless of kind, with direction determined by `subscription_kind`?
   Proposal: **Yes**, `price` is always positive (absolute value). Direction is inferred from kind.
2. **Built-in "SALARY" category** — does every user have a built-in SALARY category?
   Action: verify via `bin/rails runner 'puts User.first.categories.built_in.pluck(:category_name)'`.
3. **Bulk edit rollback UX** — should the rollback UI show a single "undo bulk edit" action
   or N individual "undo subscription" actions? Proposal: **single operation** in the
   audit timeline that rolls back all affected rows atomically.
