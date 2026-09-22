# NARUTO-05 — Pre-paid / Debit Card Support: Product and Data Contract

## Status

Planning — 2026-09-21. Not yet started.

---

## Goal

Introduce a `user_card` variant that **does not generate credit-card billing cycles**
(no `Reference` records, no invoice cash transaction generation). This covers:

- **VA / VR cards** (Vale Alimentação / Vale Refeição): pre-loaded, no bill, no due date.
- **Debit cards**: spending debits a bank account directly; no billing reference needed.
- **Other pre-paid cards**: gift cards, transport cards, any card where spending is
  direct-debit or pre-loaded.

---

## Non-Goals

- Actual bank account balance deduction (that is a `UserBankAccount.balance` concern,
  tracked separately in NARUTO-06)
- Automatic card top-up / reload modelling
- Foreign currency pre-paid cards
- Multi-account debit routing

---

## Current State

`UserCard` requires `days_until_due_date`, `due_date_day`, and `credit_limit`. All
three are mandatory. The `find_or_create_reference_for` and `calculate_reference_date`
methods assume a billing-cycle structure. The rollback adapter (`Audit::Rollback::Adapters::UserCard`)
and audit concern both exist.

`CardTransaction` requires a `user_card_id`. There is no concept of a "no-bill" card;
every `UserCard` is assumed to be a credit card with a billing reference.

---

## Proposed Data Model Change

Add a `card_kind` string-backed enum column to `user_cards`:

```sql
ALTER TABLE user_cards
  ADD COLUMN card_kind varchar NOT NULL DEFAULT 'credit';
```

Values:

| Value | Meaning |
|---|---|
| `credit` | Existing credit card behaviour — billing references, invoices, due dates |
| `prepaid` | No billing cycle; spending is direct (VA/VR, gift cards, transport) |
| `debit` | No billing cycle; spending linked to a `user_bank_account` |

### Behavioural differences by kind

| Feature | `credit` | `prepaid` | `debit` |
|---|---|---|---|
| Requires `due_date_day` | ✅ Yes | ❌ No (optional / nil) | ❌ No |
| Requires `days_until_due_date` | ✅ Yes | ❌ No | ❌ No |
| Requires `credit_limit` | ✅ Yes (spending cap) | ❌ No (balance-based) | ❌ No |
| Generates `Reference` records | ✅ Yes | ❌ No | ❌ No |
| Generates invoice cash transaction | ✅ Yes | ❌ No | ❌ No |
| Can be linked to `UserBankAccount` | — | Optional (for balance tracking) | Required |
| Appears in consolidated balance | Credit side | Pre-paid side | Debit / bank side |

### Nullable billing fields

`days_until_due_date`, `due_date_day`, and `credit_limit` are currently `NOT NULL`.
They must become nullable for non-credit cards:

```sql
ALTER TABLE user_cards
  ALTER COLUMN days_until_due_date DROP NOT NULL,
  ALTER COLUMN due_date_day DROP NOT NULL,
  ALTER COLUMN credit_limit DROP NOT NULL;
```

Or alternatively, keep them NOT NULL with a default of `0` for non-credit cards
(simpler migration, but semantically inaccurate). Preferred: **nullable**.

### `debit` kind and bank account linkage

Add an optional `user_bank_account_id` FK to `user_cards` for the `debit` variant:

```sql
ALTER TABLE user_cards
  ADD COLUMN user_bank_account_id bigint REFERENCES user_bank_accounts(id);
```

This is used by NARUTO-06 to calculate the consolidated debit balance.

---

## Behaviour Changes

### Transaction recording

- For `prepaid` and `debit` cards, `CardTransaction` creation **skips** reference
  creation (`find_or_create_reference_for` is not called).
- `CardInstallment` records are still created (installments still track payment timing),
  but they are not attached to an invoice / `Reference`.
- The "mark paid" workflow for prepaid/debit installments is simplified: no invoice
  cash transaction exists to close.

### Validation changes in `UserCard`

```ruby
validates :due_date_day, :days_until_due_date, :credit_limit,
          presence: true,
          if: :credit?
```

### `Reference` creation guard

`find_or_create_reference_for` raises or returns nil for non-credit cards. All call
sites must guard `if user_card.credit?`.

### Rollback adapter

`Audit::Rollback::Adapters::UserCard` must handle the new `card_kind` field without
breaking existing credit card rollbacks.

---

## UI Direction

### User card form

- Add a "Card type" radio / select: Credit / Pre-paid / Debit.
- Show/hide billing-cycle fields based on selection.
- For debit: show bank account selector.
- For pre-paid: no additional required fields.

### Transaction form

- No change to the user-facing flow; the card selector shows all cards regardless of kind.
- Backend silently skips reference creation for non-credit cards.

### Index / dashboard

- In the card list, a badge indicates the kind (`credit`, `prepaid`, `debit`).
- Consolidated balance (NARUTO-06) groups by kind.

---

## Implementation Slices

### Slice 1 — Migration and model changes
- Add `card_kind` column and nullable billing columns migration.
- Add `user_bank_account_id` FK migration.
- Update `UserCard` validations with `if: :credit?` guards.
- Update `find_or_create_reference_for` to no-op for non-credit.
- Update `calculate_reference_date` similarly.

### Slice 2 — Transaction flow updates
- Guard reference creation in `CardTransactionsController` / relevant service.
- Ensure `CardInstallment` creation still works without a reference.
- Update "mark paid" flow for non-credit cards.

### Slice 3 — Form and UI
- Card form kind toggle.
- Conditional billing fields.
- Debit bank account selector.

### Slice 4 — Rollback adapter and specs
- Update `Audit::Rollback::Adapters::UserCard`.
- Model specs for kind-conditional validations.
- Request specs: create prepaid card, create debit card, create transaction on each.

---

## Open Questions

1. **Existing cards**: the migration sets `card_kind DEFAULT 'credit'`, so all
   existing user cards remain credit cards. No data migration needed.
2. **VA / VR balance**: pre-paid card balances are not tracked in the app; the user
   only records spending. Balance tracking is out of scope for this ticket.
3. **Debit card installments**: does a debit card purchase make sense with N
   installments? Technically unusual but not blocked. Proposal: allow it but do not
   enforce single-installment on debit.
