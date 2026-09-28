# NARUTO-02 Bulk / Composite Transactions: Decisions and Test Matrix

## Resolved Product & Technical Decisions

### D1. What is a composite transaction and how is it detected?
**Decision**: A composite transaction is a `CashTransaction` or `CardTransaction` that has two or more `LineItem` records. The model provides a `composite?` predicate method that checks whether active (non-destroyed) line items are present.

### D2. How are line item categories and entities stored?
**Decision**: They use the existing polymorphic join tables `category_transactions` and `entity_transactions` with `transactable_type: "LineItem"`. To keep controller params and form interactions straightforward, `LineItem` exposes virtual accessors `category_id` and `entity_id` that automatically build or update the underlying join records.

### D3. What happens to the parent transaction's direct category and entity associations in composite mode?
**Decision**: They are cleared completely. When a transaction is composite, all semantic allocations reside exclusively on its `LineItem` records. Clearing parent allocations prevents double-counting across financial reports, category rollup metrics, and audit recalculations.

### D4. How are line item prices validated against the parent transaction price?
**Decision**:
1. **Sign Matching**: Every line item price must share the same sign as `parent_transaction.price`. For card transactions (which are stored with negative prices for expenses), line item prices must be negative. For positive cash transactions, line items must be positive.
2. **Non-Zero**: Line item prices cannot be 0.
3. **Exact Sum**: The sum of active line item prices must equal `parent_transaction.price` exactly.

### D5. Can a line item be assigned a parent category?
**Decision**: No. In accordance with NARUTO-01, line items must be categorized into leaf categories (`!category.parent?`). Assigning a parent category to a line item fails validation with `:must_be_leaf_category`.

### D6. How do card installments interact with line items?
**Decision**: Installments carry only payment timing (price and date). The semantic line item breakdown lives strictly on the parent `CardTransaction` and does not propagate to installments.

### D7. Can a composite transaction link to a subscription?
**Decision**: Yes. The `subscription_id` foreign key lives on the parent transaction record, allowing recurring subscriptions to be recorded as composite transactions.

### D8. What is the minimum count for line items in composite mode?
**Decision**: At least 2 line items are required. If a transaction has only 1 line item, composite mode is invalid and the purchase should be recorded as a simple transaction.

### D9. How are composite transactions audited and rolled back?
**Decision**:
- `LineItem` includes `FinancialAuditable`.
- `Audit::OwnershipResolver` handles `"LineItem"` by delegating ownership to its parent `transactable`.
- `Audit::Rollback::Adapters::LineItem` identifies the parent transaction dependency and compensates create, update, and destroy actions while triggering `%w[category_transaction_totals cash_balance]` recalculations.

### D10. How do transaction duplications behave?
**Decision**: Duplicating a composite transaction via `CashTransaction.duplicate(id)` or `CardTransaction.duplicate(id)` clones all active line items and their respective category and entity associations.

---

## Test Matrix

| Layer | File Under Test | Test Description | Expected Result |
|---|---|---|---|
| **Model** | `LineItem` | Presence of `description`, `price`, `category_id` | Invalid without required fields |
| **Model** | `LineItem` | Non-zero price validation | Rejects price == 0 |
| **Model** | `LineItem` | Sign matching validation | Rejects positive line item on negative transaction (and vice versa) |
| **Model** | `LineItem` | Leaf category validation | Rejects category where `parent? == true` |
| **Model** | `LineItem` | Virtual accessors `category_id=` and `entity_id=` | Synchronizes underlying join records |
| **Model** | `CashTransaction` | `composite?` predicate | `true` when line items >= 2, `false` when empty |
| **Model** | `CashTransaction` | Minimum count validation | Fails if exactly 1 line item is provided in composite mode |
| **Model** | `CashTransaction` | Price sum validation | Passes when sum matches parent; fails with difference when mismatched |
| **Model** | `CashTransaction` | Parent allocations clearing | Direct `category_transactions` are cleared on composite save |
| **Model** | `CardTransaction` | Negative price sum validation | Passes when sum of negative line items equals negative card price |
| **Service** | `Audit::OwnershipResolver` | Resolve ownership for `LineItem` | Inherits `owner_id` and `context_id` from parent transactable |
| **Service** | `Audit::Rollback::Adapters::LineItem` | Dependencies and parent identity | Correctly references parent `CashTransaction` / `CardTransaction` |
| **Service** | `Audit::Rollback` | Rollback composite transaction creation | Removes parent, line items, and line item join records |
| **Request** | `CashTransactionsController` | `POST /cash_transactions` with line items | Creates composite transaction with line items and leaf categories |
| **Request** | `CashTransactionsController` | `POST /cash_transactions` mismatched sum | Renders unprocessable entity with error |
| **Request** | `CardTransactionsController` | `POST /card_transactions` with line items | Creates composite card transaction; installments retain schedule |
| **Request** | `CashTransactionsController` | `GET /cash_transactions/:id/duplicate` | Clones line items and allocations |
