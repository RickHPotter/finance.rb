# NARUTO-02 Bulk / Composite Transactions: Implementation Slices

## Delivery Strategy

Implement composite transactions from the database model and audit foundation outward. Each slice delivers a
verifiable, tested capability. The test suite must pass and RuboCop must remain clean after
every slice.

---

## Slice 1: Database Migration, LineItem Model, Associations & Rollback Adapter

### Goal
Establish the `line_items` table, build the `LineItem` model with `CategoryTransactable`, `EntityTransactable`,
and `FinancialAuditable`, establish associations on `CashTransaction` and `CardTransaction`, enforce model
invariants (sign matching, leaf categories, price sum, minimum count), integrate with `Audit::OwnershipResolver`
and `Audit::Rollback::Adapters::LineItem`, and add comprehensive unit/model/rollback specs.

### Detailed Steps
1. **Database Migration**:
   - Create table `line_items`:
     ```ruby
     create_table :line_items do |t|
       t.string :transactable_type, null: false
       t.bigint :transactable_id, null: false
       t.string :description, null: false
       t.integer :price, default: 0, null: false
       t.text :comment

       t.timestamps
     end
     add_index :line_items, %i[transactable_type transactable_id]
     ```
2. **LineItem Model (`app/models/line_item.rb`)**:
   - Include standard section comments (`# @extends`, `# @includes`, `# @relationships`, etc.).
   - Includes:
     - `include CategoryTransactable`
     - `include EntityTransactable`
     - `include FinancialAuditable`
     - `audits_financial_changes`
   - Associations:
     - `belongs_to :transactable, polymorphic: true, touch: true`
   - Virtual accessors:
     - `category_id` / `category_id=` and `entity_id` / `entity_id=` to easily read and assign the single category and optional entity per line item, coordinating with `category_transactions` and `entity_transactions`.
   - Delegations:
     - `delegate :user, :context, to: :transactable, allow_nil: true`
   - Validations:
     - `validates :description, presence: true`
     - `validates :price, presence: true, numericality: { other_than: 0 }`
     - `validates :category_id, presence: true`
     - `validate :validate_leaf_category` (must not be a parent category)
     - `validate :validate_price_sign_matches_parent` (price sign must match `transactable.price` sign)
3. **Parent Models (`app/models/cash_transaction.rb` & `app/models/card_transaction.rb`)**:
   - Associations:
     - `has_many :line_items, as: :transactable, dependent: :destroy, inverse_of: :transactable`
     - `accepts_nested_attributes_for :line_items, allow_destroy: true`
   - Helpers:
     - `def composite?`: returns true when active line items (`reject(&:marked_for_destruction?)`) are present.
   - Validations:
     - `validate :validate_composite_line_items_count` (if `composite?`, must have at least 2 line items).
     - `validate :validate_line_items_price_sum` (if `composite?`, sum of active line items' price must equal `price`).
   - Callbacks:
     - Before validation / save: when `composite?`, clear direct `category_transactions` and `entity_transactions` on the parent to prevent double-counting.
4. **Audit and Rollback Integration**:
   - `Audit::OwnershipResolver`:
     - Add `when "LineItem" then resolve_association(record, :transactable)`
   - `Audit::Rollback::Adapters::LineItem`:
     - Subclass `Audit::Rollback::Adapters::Base`
     - Parent identity: `[ before_state["transactable_type"] || expected_after_state["transactable_type"], before_state["transactable_id"] || expected_after_state["transactable_id"] ]`
     - Dependencies: parent transaction (`dependency(record_type: parent_type, item_id: parent_id, relationship: :parent)`)
     - Recalculations: `%w[category_transaction_totals cash_balance]`
   - `Audit::Rollback::Registry`:
     - Register `"LineItem" => Audit::Rollback::Adapters::LineItem`
5. **Factories & Specs**:
   - `spec/factories/line_items.rb`:
     - Factory for `:line_item` associating with a cash or card transaction, a leaf category, and price.
   - `spec/models/line_item_spec.rb`:
     - Test description presence, non-zero price, category presence.
     - Test leaf category validation (reject parent category).
     - Test sign matching validation with parent transaction price.
     - Test virtual accessors `category_id` and `entity_id`.
   - `spec/models/cash_transaction_spec.rb` & `spec/models/card_transaction_spec.rb`:
     - Test `composite?` predicate.
     - Test minimum line items count (>= 2).
     - Test price sum equality validation.
     - Test clearing of parent `category_transactions` and `entity_transactions` when composite.
   - `spec/services/audit/rollback/adapters/line_item_spec.rb`:
     - Test dependencies, parent identity, compensation on create, update, and destroy.

---

## Slice 2: Controller & Nested Form Integration

### Goal
Enable `CashTransactionsController` and `CardTransactionsController` to accept `line_items_attributes`,
properly persist composite transactions, clear parent allocations when composite mode is active, handle
transaction duplication with line items, and add comprehensive request specs.

### Detailed Steps
1. **Strong Parameters**:
   - In `CashTransactionsController#cash_transaction_params`:
     - Permit `line_items_attributes: %i[id description price comment category_id entity_id _destroy]`
   - In `CardTransactionsController#card_transaction_params`:
     - Permit `line_items_attributes: %i[id description price comment category_id entity_id _destroy]`
2. **Controller Pre-processing / Normalization**:
   - When `line_items_attributes` has active records, mark any submitted header `category_id` or `entity_id` as cleared so only line items carry allocations.
   - In `CashTransaction.duplicate` and `CardTransaction.duplicate`:
     - Duplicate active line items (and their category and entity associations) onto the duplicated transaction.
3. **Request Specs**:
   - `spec/requests/cash_transactions_spec.rb`:
     - Create composite cash transaction with 2+ line items and verify line items and their categories are saved.
     - Verify parent category/entity join records are absent.
     - Attempt to create composite cash transaction with mismatched price sum -> fails with validation error.
     - Attempt to create composite cash transaction with only 1 line item -> fails with validation error.
     - Update composite cash transaction (edit description/price, add new line item, delete line item).
   - `spec/requests/card_transactions_spec.rb`:
     - Create composite card transaction with negative prices matching card transaction price.
     - Verify card installments have correct total price while line items remain on the card transaction.
     - Duplicate a composite card transaction and confirm line items are cloned.

---

## Slice 3: Front-End / UI Form Component & Stimulus

### Goal
Introduce the "Split purchase" toggle and dynamic line items form in `Views::CashTransactions::Form` and
`Views::CardTransactions::Form`, allowing users to dynamically add, edit, and remove line item rows with
running total tracking and currency masking.

### Detailed Steps
1. **Phlex Components**:
   - Create `Views::Transactions::FormLineItemsSection`:
     - Rendered within `Views::CashTransactions::Form` and `Views::CardTransactions::Form`.
     - "Split purchase" switch / toggle button.
     - Running summary bar: Parent Total, Allocated Sum, Difference badge.
     - Line items table/list:
       - Description input
       - Price input (masked with `data-controller="price-mask"`)
       - Category single-select combobox (restricted to leaf categories, displaying hierarchical name)
       - Entity single-select combobox
       - Remove row button
     - "Add item" button.
     - Hidden template for dynamic record insertion (`child_index: "NEW_LINE_ITEM"`).
2. **Stimulus Integration**:
   - Create or extend `composite_transaction_controller.js`:
     - Toggles line items section visibility.
     - When split mode is enabled, disables header category/entity comboboxes and marks header allocations for destruction.
     - When split mode is disabled, removes line item rows and re-enables header category/entity comboboxes.
     - Listens to line item price input changes and updates the running allocated total and difference indicator.
     - Supports adding and removing line item rows dynamically.
3. **Form Skeleton Alignment**:
   - Update `Views::CashTransactions::FormSubmissionSkeleton` and `Views::CardTransactions::FormSubmissionSkeleton`
     if necessary to account for composite form submissions.

---

## Slice 4: Transaction Display (Index & Show Views)

### Goal
Provide clear visual breakdown and indicators for composite transactions across show and index views.

### Detailed Steps
1. **Transaction Show View (`Views::CashTransactions::Show` & `Views::CardTransactions::Show`)**:
   - When `transaction.composite?`:
     - Render a dedicated "Line Items" breakdown card/section.
     - Table columns: Description, Category (with compound hierarchy badge), Entity (with avatar), Price, Percentage of Total.
2. **Transaction Index / Installments Table (`Views::CashInstallments::Index` & `Views::CardInstallments::Index`)**:
   - On table rows for composite transactions:
     - Render a distinct compound badge (e.g. `Split [N items]`).
     - Display a popover or expandable toggle revealing the line item breakdown without navigating away.
3. **Category Popover & Presentation**:
   - When displaying categories for a composite transaction row, gather distinct categories from line items.

---

## Slice 5: Verification, Audit Trail & Rollback Integration

### Goal
Verify the complete end-to-end lifecycle: creating composite transactions, updating line items, rolling
back operations, and confirming CI pass.

### Detailed Steps
1. **Audit & Rollback Verification**:
   - Create full integration specs verifying that rolling back an operation that created a composite transaction
     cleanly removes the parent transaction, line items, and line item allocations.
   - Verify that rolling back an edit restores previous line item prices and descriptions.
2. **Run Full Verification Suite**:
   - `bin/rubocop -A`
   - `bin/rspec spec/models/line_item_spec.rb`
   - `spec/models/cash_transaction_spec.rb`
   - `spec/models/card_transaction_spec.rb`
   - `spec/services/audit/rollback/adapters/line_item_spec.rb`
   - `spec/requests/cash_transactions_spec.rb`
   - `spec/requests/card_transactions_spec.rb`
   - `bin/ci`
