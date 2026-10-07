# NARUTO-02 — Bulk / Composite Transactions: Product and Data Contract

## Status

Approved planning contract as of 2026-09-28.

---

## Goal

Allow a user to record **one real-world purchase** (e.g., an Amazon order, a
supermarket trip, or a home supply run) that spans multiple categories and/or
entities, distributing the total across named **line items**. Each line item knows
its own category, optional entity, price, and description. The parent transaction
stays the payment record; the line items provide the semantic breakdown.

---

## Motivation

Current pain point: buying groceries for yourself, a leisure item for your spouse, and
a home asset (all from the same basket / order / payment) requires three separate
transactions. The subscription-reference model groups related transactions
under an intent; this ticket adds **within-transaction breakdown** via line items.

---

## Non-Goals

- Multi-payment splitting (that is an exchange / advance payment concern already solved)
- Budget allocation per line item (deferred — budget model is separate)
- Bulk card installment splitting across line items (installments track payment timing, breakdown lives on the parent)
- Cross-context line items (all line items inherit parent's context)
- Recurring line item templates
- CSV import of composite transactions (deferred)

---

## Vocabulary

| Term | Meaning |
|---|---|
| **Composite transaction** | A `CashTransaction` or `CardTransaction` that has two or more `LineItem` records |
| **Line item** | A named sub-entry (`LineItem`) with its own price, leaf category, and optional entity |
| **Parent transaction** | The composite record (`CashTransaction` or `CardTransaction`) that carries the payment instrument, date, and total price |
| **Simple transaction** | An existing transaction without line items (unchanged behaviour) |

---

## Data Model

### New table: `line_items`

```sql
CREATE TABLE line_items (
  id                bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  transactable_type varchar NOT NULL,   -- 'CashTransaction' | 'CardTransaction'
  transactable_id   bigint NOT NULL,
  description       varchar NOT NULL,
  price             integer NOT NULL DEFAULT 0,
  comment           text,
  created_at        timestamp(6) without time zone NOT NULL,
  updated_at        timestamp(6) without time zone NOT NULL
);

CREATE INDEX index_line_items_on_transactable ON line_items(transactable_type, transactable_id);
```

### Allocation Join Tables: `category_transactions` and `entity_transactions`

No schema change needed. The polymorphic `transactable_type` / `transactable_id` pair
accepts `"LineItem"` as a source type.

Line items include `CategoryTransactable`, `EntityTransactable`, and `FinancialAuditable`.
To keep forms and services clean, `LineItem` exposes virtual accessors for `category_id`
and `entity_id` that transparently manage the underlying join records (`category_transactions`
and `entity_transactions`).

### Relationship to Parent Transaction

- `CashTransaction` / `CardTransaction`: `has_many :line_items, as: :transactable, dependent: :destroy`
- `accepts_nested_attributes_for :line_items, allow_destroy: true`
- **Parent Allocations Cleared in Composite Mode**: When line items are present (`composite?`),
  the parent transaction's direct `category_transactions` and `entity_transactions` are
  cleared completely. All semantic category and entity allocations live exclusively on the
  line items. This prevents duplicate counting in financial reports, category rollup metrics,
  and audit recalculations.
- Parent `price` = sum of `line_items.price` (enforced by validation).

---

## Invariants

| Invariant | Enforcement |
|---|---|
| Parent price must equal sum of line item prices | Model validation on parent (`validate_line_items_price_sum`) |
| At least two line items if composite mode is active | Model validation on parent (`validate_composite_line_items_count`) |
| Line item prices must match parent transaction price sign | Model validation on `LineItem` (`validate_price_sign_matches_parent`) |
| Line item price cannot be zero | Model validation on `LineItem` (`numericality: { other_than: 0 }`) |
| Line item description presence | Model validation on `LineItem` (`validates :description, presence: true`) |
| Category on each line item must be a leaf (not a parent) | Model validation on `LineItem` (`validate_leaf_category`) |
| Category presence on line item | Model validation on `LineItem` (`validates :category_id, presence: true`) |
| A simple transaction (no line items) is unaffected | Existing validation and persistence paths unchanged |
| Line items belong to the same context as the parent | Inferred through `transactable` ownership |

---

## UI Direction

### Entry Form

The transaction create / edit form gains a **"Split purchase"** toggle button. When activated:
- The single-category / single-entity fields in the header controls are hidden.
- A dynamic line-item builder is displayed.
- Each line item row contains:
  - Description input
  - Price input (currency-masked)
  - Category combobox (limited to leaf categories)
  - Optional entity combobox
  - Remove line item button
- A running summary bar shows:
  - Total transaction price
  - Allocated sum of line items
  - Remaining unallocated amount (highlighted in red if non-zero, green when balanced)
- "Add line item" button to append rows dynamically.

Split purchase is available for ordinary purchases and exchange requests, including
`BORROW RETURN` transactions, where one transaction can allocate amounts to multiple
entities (including the current user). It is unavailable for generated `EXCHANGE RETURN`
transactions and other system-managed transaction types such as card payments, card
advances, investments, and piggy-bank projections.

### Display / Show

- Composite transactions display a collapsible line-item breakdown beneath the transaction header row in show and index views.
- Category badges on the parent row render a compound summary badge (e.g. `Split [N categories]` or multiple category pills).
- Entity badges aggregate distinct entities involved across line items.

---

## Rollback & Financial Auditing

### Audit Trail
- `LineItem` includes `FinancialAuditable`.
- Creating, updating, or destroying line items generates `AuditVersion` records under the current `AuditOperation`.
- `Audit::OwnershipResolver` handles `"LineItem"` by delegating to its `transactable` (`CashTransaction` or `CardTransaction`).

### Rollback Adapter: `Audit::Rollback::Adapters::LineItem`
- Registers in `Audit::Rollback::Registry`.
- Parent identity is `[ transactable_type, transactable_id ]`.
- Rollback dependencies point to the parent transaction (`CashTransaction` or `CardTransaction`).
- Recreating on rollback creates the `LineItem` record and cascades to recreate its associated `category_transactions` and `entity_transactions`.
- Destroying on rollback removes the `LineItem` and cascades to dependent allocations.
- Recalculations: `%w[category_transaction_totals cash_balance]`.

---

## Resolved Architectural Decisions

1. **Card installments and line items**: Installments carry only price and payment date; the line item breakdown lives strictly on the parent `CardTransaction`.
2. **Subscription attachment**: The `subscription_id` foreign key lives on the parent transaction; composite transactions may link to subscriptions as usual.
3. **Parent allocations**: Cleared completely when composite mode is active so allocations reside exclusively on line items without double-counting.
4. **Line item sign matching**: Line item prices must share the sign of the parent transaction (both negative for expense card transactions, or matching sign for cash transactions).
5. **Direct virtual accessors**: `LineItem#category_id` and `LineItem#entity_id` provide clean accessors that coordinate with underlying polymorphic join tables.
