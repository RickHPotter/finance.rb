# NARUTO-01 Category Hierarchy: Product and Data Contract

## Status

Approved planning contract as of 2026-09-25.

---

## Goal

Allow users to organise categories into a two-level hierarchy: a **parent category**
(group label, e.g. `"HSH"` for Home Sweet Home) and its **child categories** (functional leaves,
e.g. `"SUPPLIES"`, `"LAND & PROPERTY"`, `"LABOUR"`).

- **Clean Naming**: Child categories are named cleanly without repeating the parent prefix
  (e.g. `"LABOUR"`, not `"HSH - LABOUR"`).
- **Scoped Uniqueness**: Category names are unique within their parent scope (`user_id` + `parent_category_id`),
  enabling different parents to each have a child named `"SUPPLIES"` (e.g. `"HSH" -> "SUPPLIES"` vs `"ASSETS" -> "SUPPLIES"`).
- **Direct Transactions on Parents Allowed**: A parent category can receive transactions directly
  (for one-off, niche, or general expenses where creating a subcategory is unnecessary, e.g. `"ASSETS - KALEIDOSCOPE"`,
  as well as during transition when adding children to an existing category).
- **Compound Visual Display**: When a child category is rendered, it is visually wrapped in its parent context:
  `[ HSH [ LABOUR ] ]`, whereas standalone or parent categories render as `[ HSH ]`.
- **Hierarchical Querying & Filtering**: Filtering by a parent category encompasses the parent and all its
  subcategories. Filtering by a specific child category selects only that child.

---

## Motivation & Real-World Use Case

In personal finance, flat category lists quickly become cluttered when tracking multi-faceted
projects or departments:
- A real estate project (`HSH`) encompasses land assets, raw construction supplies, contractor labour, and permits.
- A vehicle maintenance domain (`AUTO`) covers insurance, fuel, scheduled service, and detailing.
- A family project (`BABY`) covers medical, nursery furniture, clothing, and consumables.

Currently, users either create flat prefixed categories (e.g. `HSH - LABOUR`), which clutter all
selectors and flat summaries without grouping, or lump everything into one generic `HSH` category
losing semantic granularity. Category hierarchy gives users clean grouping on indexes and selectors
without compromising individual transaction precision or requiring redundant prefixes.

---

## Non-Goals

- **Three or more levels of nesting**: The hierarchy is strictly two levels (parent → child). No grandchildren.
- **Budget category hierarchy**: `BudgetCategory` remains mapped to individual categories in this sprint. Roll-up budgets across parent categories are deferred.
- **Automatic cross-user category sharing**: Categories remain strictly private and scoped to a single `user_id`.
- **Automatic name mutation**: Renaming a parent category does not automatically rename child category string names.

---

## Vocabulary

| Term | Definition |
|---|---|
| **Standalone Category** | A category with no `parent_category_id` and zero children. Functions exactly like existing legacy categories. |
| **Parent Category** | A category that has one or more child categories (`subcategories.any?`). Can have its own direct transactions and serves as a grouping header. |
| **Child Category (Subcategory)** | A category that has a `parent_category_id` pointing to a parent category. Named cleanly (e.g. `LABOUR`), unique within that parent. |
| **Subtree / Category Family** | A parent category plus all of its immediate child categories (`category.subtree_ids = [category.id] + category.subcategory_ids`). |
| **Roll-up Metric** | On a parent category, the aggregated sum of transactions count and totals calculated from the parent's direct transactions plus all of its child categories. |

---

## Data Model & Schema Changes

### Schema Change on `categories`

1. Add a nullable foreign key column `parent_category_id` to `categories`, self-referencing `categories(id)`:
```sql
ALTER TABLE categories
  ADD COLUMN parent_category_id bigint REFERENCES categories(id) ON DELETE RESTRICT;

CREATE INDEX index_categories_on_parent_category_id ON categories(parent_category_id);

-- Prevent immediate self-parenting at the database level:
ALTER TABLE categories
  ADD CONSTRAINT categories_no_self_parent
  CHECK (parent_category_id IS NULL OR parent_category_id <> id);
```

2. Update Uniqueness Constraint:
Drop the old `(user_id, category_name)` index and replace it with a unique index considering `parent_category_id`:
```sql
DROP INDEX index_category_name_on_composite_key;

-- PostgreSQL 15+ supports NULLS NOT DISTINCT:
CREATE UNIQUE INDEX index_categories_on_user_id_parent_and_name
  ON categories (user_id, parent_category_id, category_name) NULLS NOT DISTINCT;
```
*Note*: With `NULLS NOT DISTINCT`, two top-level categories (`parent_category_id IS NULL`) cannot share the same name,
while two children under different parents can each be named `"SUPPLIES"`.

### Table Schema Summary

| Column | Type | Nullable | Notes |
|---|---|---|---|
| `id` | bigint | No | Primary key |
| `category_name` | character varying | No | Unique per `(user_id, parent_category_id)` |
| `parent_category_id` | bigint | Yes | Self-reference foreign key to parent `categories.id` |
| `user_id` | bigint | No | Owner foreign key |
| `active` | boolean | No | Default `true` |
| `built_in` | boolean | No | Default `false` |
| `colour` | character varying | No | Hex color (`#ffffff`) |
| `text_colour_mode` | character varying | No | `automatic` or `manual` |
| `text_colour` | character varying | Yes | Hex color when manual |
| Counters & totals | integer | No | Direct transaction counters: `card_transactions_count/total`, `cash_transactions_count/total` |

---

## Invariants & Validation Rules

### 1. Depth Limit (Strictly Two Levels)
- A category with `parent_category_id.present?` cannot itself be a parent to other categories.
- If category B has `parent_category_id = A`, no category C can have `parent_category_id = B`.
- Validated in `Category#validate_hierarchy_depth`:
  - `errors.add(:parent_category_id, :cannot_be_child_of_child)` if `parent_category&.parent_category_id.present?`.
  - `errors.add(:parent_category_id, :cannot_have_parent_when_has_children)` if `parent_category_id.present? && subcategories.any?`.

### 2. User Boundary & Ownership
- A category and its parent must belong to the exact same `user_id`.
- Validated in `Category#validate_parent_ownership`:
  - `errors.add(:parent_category_id, :must_belong_to_same_user)` if `parent_category && parent_category.user_id != user_id`.

### 3. Built-in Categories Cannot Be Parents or Children
- System built-in categories (`built_in: true`, such as `EXCHANGE`, `PIGGY BANK`, `CARD PAYMENT`, `SUBSCRIPTION`, `INVESTMENT`)
  cannot have a parent, nor can they be chosen as a parent for custom categories.
- Validated in `Category#validate_built_in_hierarchy`:
  - `errors.add(:parent_category_id, :built_in_cannot_have_parent)` if `built_in? && parent_category_id.present?`.
  - `errors.add(:parent_category_id, :built_in_cannot_be_parent)` if `parent_category&.built_in?`.

### 4. Direct Transactions Permitted on All Categories
- Both parent categories and child categories are eligible to receive `CategoryTransaction` records.
- Standalone transactions or broad niche items can be assigned directly to the parent (e.g. `"HSH"` or `"ASSETS"`).
- Adding a child category to a category that already has direct transactions is fully supported and valid.

### 5. Deletion & Destruction Restrictions
- A parent category cannot be deleted while it has child categories:
  - `has_many :subcategories, class_name: "Category", foreign_key: :parent_category_id, dependent: :restrict_with_error`.
- The database foreign key uses `ON DELETE RESTRICT`.

### 6. Active Status Cascade
- If a parent category is deactivated (`active: false`), its child categories are automatically deactivated:
  - When updating a parent category with `active: false`, a callback/service cascades deactivation to all its `subcategories`.
  - Validation: a child cannot be marked `active: true` if its `parent_category` is `active: false`.

---

## UI & Interaction Contract

### 1. Visual Badge Representation (`Components::CategoryBadge`)

- **Standalone or Parent Category**:
  Renders as a standard category badge with its configured colour and contrast:
  `[ HSH ]`
- **Child Category**:
  Renders with a compound/nested visual presentation:
  `[ HSH [ LABOUR ] ]`
  - The outer frame reflects the parent identity (e.g. parent name and subtle parent border/swatch).
  - The inner frame reflects the child category's own specific name and color styling.
  - On compact surfaces, this presents as `HSH: LABOUR` or a nested badge structure, giving the user immediate, unambiguous context.

### 2. Category Form (`Views::Categories::Form`)

- **Parent Selector**:
  - Optional dropdown / select field: `"Group / Parent Category"` (`parent_category_id`).
  - Options list: Top-level custom categories belonging to `current_user` (`where(parent_category_id: nil, built_in: false)`), excluding `category.id` (self).
  - Blank option: `"None (Standalone / Top-Level Category)"`.
  - If the category already has subcategories, the parent selector is disabled with an informative note: `"This category has subcategories and cannot have a parent."`
  - If the category has existing transactions, selecting a parent or adding children is allowed.

- **Name Input**:
  - Placeholder: `"Category Name (e.g. LABOUR)"`.
  - Scoped uniqueness validation: If another category with the same name exists under a *different* parent, it is valid! If another category with the same name exists under the *same* parent, it displays a localized validation error.

### 3. Category Index View (`Views::Categories::Index` & `Views::Categories::Category`)

- **Desktop Table (`desktop_row`)**:
  - Parent row:
    - Displayed with parent badge (`[ HSH ]`).
    - Status: Active / Inactive badge.
    - Card Transactions Count & Total: Shows **roll-up sum** (parent's own direct transactions + all children's transactions).
    - Cash Transactions Count & Total: Shows **roll-up sum** (parent's own direct transactions + all children's transactions).
    - If the parent has direct transactions, a small hint or badge displays direct vs child contribution (e.g. `"Total: 12 (2 direct, 10 in 3 subcategories)"`).
    - Actions: Edit parent, Delete (disabled if children exist), `+ Subcategory` shortcut.
  - Child row:
    - Nested beneath its parent with visual indentation (`ml-6` / `pl-4` border-l).
    - Compound badge: `[ HSH [ LABOUR ] ]`.
    - Displays its own direct transaction counts and totals.
    - Direct jump links to card and cash transactions filtered by that child `category_id`.
    - Actions: Edit, Merge, Delete.

- **Mobile Card View (`mobile_row`)**:
  - Group card: Parent category header with child count badge (e.g. `"3 subcategories"`).
  - Roll-up transaction metrics clearly labeled on the parent card.
  - Children cards render neatly indented directly beneath the parent card.

### 4. Transaction Form & Combobox Selector

- **Transaction Category Combobox (`SingleSelectCombobox`)**:
  - Both parent and child categories are available for selection!
  - Presentation:
    - Parent categories appear with a distinct group styling or prefix (e.g. `HSH (Parent)` or bold header).
    - Child categories appear indented under their parent, formatted as `HSH / LABOUR`.
  - **Search & Ranking Integration (KAKASHI-18)**:
    - Each child category carries its parent name as an alias token.
    - When the user types `"HSH"`, the parent `"HSH"` matches, and all of its children (`"LABOUR"`, `"SUPPLIES"`, `"LAND & PROPERTY"`) also match immediately in search results.
    - If the user selects `"HSH"`, the transaction is tagged directly to the parent category.
    - If the user selects `"LABOUR"`, the transaction is tagged to the child category.

### 5. Hierarchical Filtering & Queries

When filtering transactions by `category_id` (in transaction search, cash/card index filters, ledgers, or reports):
- **Filtering by a Child Category**:
  Selects transactions tagged specifically to that child category:
  `where(category_id: child.id)`.
- **Filtering by a Parent Category**:
  Selects transactions tagged to the parent **plus** transactions tagged to any of its subcategories:
  `where(category_id: parent.subtree_ids)`.
  This allows the user to see all "HSH" expenses at once, or drill down to "HSH - LABOUR" specifically.

---

## Inter-System & Service Contracts

### 1. Category Merges (`CategoryMerges::Planner`)
In `app/services/category_merges/planner.rb`:
- **Merging into a Parent**:
  Allowed! Since parent categories can receive transactions, merging a category into a parent category simply transfers the transactions to the parent.
- **Merging a Parent that has Subcategories**:
  If `source.parent?`: Blocked with conflict `:source_has_children` unless all children are re-parented or deleted first. Merging a parent should not silently orphan or delete its subcategories.

### 2. Allocation Mutations (`AllocationMutations::CategoryPlanner`)
In `app/services/allocation_mutations/category_planner.rb`:
- Bulk category actions (`Add Category`, `Switch Category`) support both parent and child categories, since all categories are valid transaction assignees.

### 3. Financial Auditing & Rollback (`Audit::Rollback::Adapters::Category`)
- `parent_category_id` is an audited attribute in PaperTrail changesets.
- If a child category was deleted and rolled back:
  - If the parent still exists, `parent_category_id` is restored.
  - If the parent was deleted in the interim, rollback restores the category as standalone (`parent_category_id: nil`) to prevent foreign key errors, accompanied by an audit note.

---

## Resolved Decisions Summary

1. **Child Naming**: Clean names without redundant parent prefixes (e.g. `"LABOUR"`, not `"HSH - LABOUR"`).
2. **Name Uniqueness**: Scoped to `(user_id, parent_category_id)` with `NULLS NOT DISTINCT`. Different parents can each have a child with the same name (e.g. `"SUPPLIES"`).
3. **Direct Transactions on Parents**: Fully permitted. Useful for niche/standalone one-offs and smooth transition.
4. **Visual Badge**: `[ HSH [ LABOUR ] ]` compound badge for child categories.
5. **Hierarchical Filtering**: Filtering by parent selects parent + all subcategories. Filtering by child selects only that child.
6. **Roll-up Metrics**: Parent rows display the aggregated sum of direct parent transactions + all subcategories.
