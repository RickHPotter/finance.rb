# NARUTO-02 — Bulk / Composite Transactions: Product and Data Contract

## Status

Planning — 2026-09-21. Not yet started.

---

## Goal

Allow a user to record **one real-world purchase** (e.g., an Amazon order, a
supermarket trip, or a home supply run) that spans multiple categories and/or
entities, distributing the total across named **line items**. Each line item knows
its own category, entity, price, and optional description. The parent transaction
stays the payment record; the line items are the semantic breakdown.

---

## Motivation

Current pain point: buying groceries for yourself, a leisure item for your spouse, and
a home asset (all from the same basket / order / payment) requires three separate
transactions. The subscription-reference model already groups related transactions
under an intent; this ticket adds **within-transaction breakdown** via line items.

---

## Non-Goals

- Multi-payment splitting (that is an exchange / advance payment concern already solved)
- Budget allocation per line item (deferred — budget model is separate)
- Bulk card installment splitting across line items
- Cross-context line items
- Recurring line item templates

---

## Vocabulary

| Term | Meaning |
|---|---|
| **Composite transaction** | A `CashTransaction` or `CardTransaction` that has at least one `LineItem` |
| **Line item** | A named sub-entry with its own price, category, and optional entity |
| **Parent transaction** | The composite record that carries the payment instrument, date, and total price |
| **Simple transaction** | An existing transaction without line items (unchanged behaviour) |

---

## Data Model

### New table: `line_items`

```sql
CREATE TABLE line_items (
  id              bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  transactable_type varchar NOT NULL,   -- 'CashTransaction' | 'CardTransaction'
  transactable_id   bigint NOT NULL,
  description       varchar NOT NULL,
  price             integer NOT NULL DEFAULT 0,
  comment           text,
  created_at        timestamp NOT NULL,
  updated_at        timestamp NOT NULL
);

CREATE INDEX index_line_items_on_transactable ON line_items(transactable_type, transactable_id);
```

Line items carry their own category and entity through existing join tables
(`category_transactions` / `entity_transactions`) using the same polymorphic
`transactable` pattern already used by `CardTransaction` and `CashTransaction`.

### `category_transactions` and `entity_transactions`

No schema change needed. The polymorphic `transactable_type` / `transactable_id` pair
will accept `"LineItem"` as a new source type.

### Relationship to parent transaction

- `CashTransaction` / `CardTransaction`: `has_many :line_items, as: :transactable`
- When line items are present, `category_transactions` and `entity_transactions` on
  the **parent** are considered deprecated for that composite record. The parent's
  category/entity fields are cleared or set to a built-in "COMPOSITE" sentinel.
- Parent `price` = sum of `line_items.price` (validated / auto-computed).

---

## Invariants

| Invariant | Enforcement |
|---|---|
| Parent price must equal sum of line item prices | Model validation on parent |
| At least two line items if composite mode is activated | Model validation |
| A simple transaction (no line items) is unaffected | Existing paths unchanged |
| Category on each line item must be a leaf (not a parent) | Validation via NARUTO-01 |
| Line items belong to the same context as the parent | Implicit (transactable context) |

---

## UI Direction

### Entry form

The transaction create / edit form gains a **"Split purchase"** toggle. When activated:
- The single-category / single-entity fields are replaced by a dynamic line-item
  list builder.
- Each line item row: description, price (currency masked), category selector,
  optional entity selector.
- A running total shows how much of the parent price has been allocated vs. remaining.
- Validation highlights the difference if the sum does not match the parent total.

### Display / show

- Composite transactions display a collapsible line-item breakdown beneath the
  transaction header row.
- Category and entity badges on the parent row show a stacked multi-badge or a
  "N categories" summary badge.

### Review / monthly analysis

- Line items contribute their own category / entity to reporting. The parent
  transaction price is **not** double-counted; only line items roll up into category
  totals when the transaction is composite.
- Audit trail: line item create / update / destroy events are tracked via
  `FinancialAuditable` on `LineItem`.

---

## Rollback

A rollback adapter `Audit::Rollback::Adapters::LineItem` is required. It should:
- Remove created line items on rollback of a composite transaction creation.
- Re-apply line item state on rollback of an edit that altered line items.
- Cascade rollback to `category_transactions` and `entity_transactions` on the line items.

---

## Implementation Slices

### Slice 1 — Data model and LineItem model
- Migration: `line_items` table.
- `LineItem` model with `CategoryTransactable`, `EntityTransactable`, `FinancialAuditable`.
- Associations on `CashTransaction` / `CardTransaction`.
- Model validations: price sum, minimum count, leaf category.
- Rollback adapter stub.

### Slice 2 — Controller and form
- Update `CashTransactionsController` / `CardTransactionsController` to accept
  `line_items_attributes`.
- Stimulus controller for dynamic line-item list (add/remove rows, running total).
- Server-side rendering of line item list in Phlex.

### Slice 3 — Display and reporting
- Transaction show / index: collapsible line item breakdown.
- Monthly analysis: route category / entity totals through line items when composite.

### Slice 4 — Specs and rollback
- Model specs: validation, price sum, cascade.
- Request specs: create composite cash and card transactions.
- Service specs: rollback adapter.

---

## Open Questions

1. **Card installments and line items** — when a composite card transaction is split
   into installments, do the installments also know about line items? Proposal: **No**,
   installments carry only price/date; the breakdown lives on the parent transaction.
2. **Importing** — does the CSV importer need to handle line items? Proposal: **Deferred**
   to a later import enhancement.
3. **Subscription attachment** — can a composite transaction be linked to a subscription?
   Proposal: **Yes**, the `subscription_id` FK already lives on the parent transaction.
