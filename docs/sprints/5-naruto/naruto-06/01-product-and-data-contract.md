# NARUTO-06 — Consolidated Balance Dashboard: Product and Data Contract

## Status

Planning — 2026-09-21. Not yet started.

---

## Goal

Present a single **Balance Dashboard** that answers, in real time:

> *"How much money do I effectively have, and how much of my credit is available?"*

This includes:

1. **Credit card balances** — for each credit `UserCard`: credit limit, current used
   amount (sum of unpaid installments for the current billing period), cofrinho
   (guaranteed minimum limit / piggy-bank reserve), and net available credit.
2. **Pre-paid card balances** — current recorded balance (sum of top-ups minus spending).
   *(No external API; user-recorded only, NARUTO-05 scope.)*
3. **Bank account / debit balances** — current balance of each `UserBankAccount`
   (already stored as `user_bank_accounts.balance`).

---

## Non-Goals

- Live bank API / Open Finance integration (deferred)
- Multi-currency consolidation
- Investment and piggy bank balances (they have their own pages)
- Historical balance trend chart (deferred)
- Budget vs. actual comparison (budget is a separate concern)

---

## Vocabulary

| Term | Meaning |
|---|---|
| **Credit limit** | `user_cards.credit_limit` (stored, user-declared) |
| **Used credit** | Sum of unpaid `CardInstallment.price` for the card's current and future open billing periods |
| **Cofrinho / piggy reserve** | A user-defined reserve amount set aside inside the credit limit that the user does not intend to spend (guaranteed limit buffer) |
| **Net available credit** | `credit_limit - used_credit - cofrinho_reserve` |
| **Pre-paid balance** | Running tally of top-up credits minus spending on a pre-paid card (user-recorded, no bank API) |
| **Bank balance** | `user_bank_accounts.balance` (manually updated or updated via future import) |

---

## Data Model Changes

### Credit card: cofrinho reserve

Add a nullable `cofrinho_reserve_cents` integer column to `user_cards`:

```sql
ALTER TABLE user_cards
  ADD COLUMN cofrinho_reserve_cents integer;
```

This is the amount the user mentally sets aside from their credit limit (e.g., keeps
R$ 2 000 always unspent as a safety buffer). Nullable means "not set / not applicable".

No constraint on maximum value, but a model validation ensures
`cofrinho_reserve_cents <= credit_limit` when both are present.

### Used credit calculation

No new column. Computed at query time:

```ruby
# For a given user_card and context:
used_credit = user_card.card_installments
  .joins(:card_transaction)
  .where(paid: false)
  .where(card_transactions: { context_id: current_context.id })
  .sum(:price)
```

This already maps to the existing `card_installments` data. For performance, a
`UserCard#used_credit(context:)` instance method wraps this query.

### Pre-paid card balance

No new column for this sprint. Pre-paid balance is computed as:

```
pre-paid balance = (sum of top-up cash_transactions tagged to the card as incoming)
                 - (sum of card_transactions.price on that card)
```

This requires a convention: a cash transaction credited to a pre-paid card is recorded
as a cash transaction on the linked bank account with the pre-paid `UserCard` referenced
in metadata, OR as a dedicated "top-up" `CardTransaction` with negative price (refund
direction). The exact convention will be defined in NARUTO-05 and referenced here.

For V1: **show spending total only**; top-up tracking is deferred to NARUTO-05 v2.

---

## Dashboard Layout

### Desktop

```
┌─────────────────────────────────────────────────────────┐
│  Balance Overview                           as of today  │
├──────────────────┬──────────────────┬───────────────────┤
│  Credit Cards    │  Pre-paid Cards  │  Bank Accounts    │
│                  │                  │                   │
│  Nubank          │  VR              │  Itaú Checking    │
│  Limit  R$ 5000  │  Spent R$ 312    │  Balance R$ 8 200 │
│  Used   R$ 1200  │                  │                   │
│  Cofrin R$  500  │  Ticket VA       │  Nubank PJ        │
│  Avail  R$ 3300  │  Spent R$ 89     │  Balance R$ 3 100 │
│                  │                  │                   │
│  C6 Bank         │                  │                   │
│  Limit  R$ 3000  │                  │                   │
│  Used   R$  400  │                  │                   │
│  Cofrin R$    0  │                  │                   │
│  Avail  R$ 2600  │                  │                   │
├──────────────────┴──────────────────┴───────────────────┤
│  Total net credit available: R$ 5 900                   │
│  Total bank balance:         R$ 11 300                  │
│  Combined liquid position:   R$ 17 200                  │
└─────────────────────────────────────────────────────────┘
```

### Mobile

Each section (Credit / Pre-paid / Bank) stacks vertically as a collapsible card.

---

## Calculation Definitions

### Per credit card

```
used_credit     = sum(unpaid card_installments.price for this card and current context)
net_available   = credit_limit - used_credit - cofrinho_reserve_cents.to_i
```

### Portfolio totals

```
total_net_credit   = sum(net_available) for all active credit user_cards
total_bank_balance = sum(balance) for all active user_bank_accounts
combined_liquid    = total_net_credit + total_bank_balance
```

*Note*: `combined_liquid` is an optimistic maximum — it conflates available credit
(not money you own) with actual cash. The dashboard will label these clearly.

---

## Implementation Slices

### Slice 1 — Data model
- Migration: add `cofrinho_reserve_cents` to `user_cards`.
- `UserCard#used_credit(context:)` method.
- `UserCard#net_available_credit(context:)` method.
- Model spec for both methods.

### Slice 2 — Balance service / presenter
- `Logic::BalanceDashboard` (or presenter object) that assembles:
  - Credit cards with limit / used / cofrinho / available.
  - Pre-paid cards with spent total.
  - Bank accounts with balance.
  - Portfolio totals.
- Spec: service/presenter spec with stubbed data.

### Slice 3 — Dashboard route and view
- Route: `GET /balance` (or nested under dashboard).
- Controller: `BalanceController#index`.
- Phlex view: `Views::Balance::Index` with three column sections.
- Mobile-responsive stacked layout.

### Slice 4 — Cofrinho edit on UserCard form
- Add `cofrinho_reserve_cents` field to the user card edit form.
- Currency-masked input.
- Request spec: update cofrinho.

### Slice 5 — Specs
- Model specs: `used_credit`, `net_available_credit`, cofrinho validation.
- Request spec: balance dashboard access, context isolation.

---

## Open Questions

1. **Context scoping** — should the balance dashboard use the current context, or
   aggregate across all user contexts? Proposal: **current context only** for V1,
   with an "all contexts" toggle deferred.
2. **Live vs. cached used_credit** — for users with many installments, summing at
   request time may be slow. Should `used_credit` be stored as a counter cache on
   `user_cards`? Proposal: **compute at request time for V1**; add counter cache if
   profiling reveals a problem.
3. **Pre-paid balance convention** — see NARUTO-05 open question on top-up recording.
   This ticket's V1 shows only spending totals, deferring true balance until NARUTO-05
   defines the top-up recording convention.
4. **Cofrinho name in UI** — use "Reserve" in English, "Cofrinho" in pt-BR as the
   label. Already consistent with existing piggy bank / cofrinho terminology in the app.
