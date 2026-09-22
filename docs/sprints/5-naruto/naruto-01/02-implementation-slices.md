# NARUTO-01 Category Hierarchy: Implementation Slices

## Delivery Strategy

Implement the category hierarchy from the database model outward. Each slice delivers a
verifiable, tested capability. The test suite must pass and RuboCop must remain clean after
every slice.

---

## Slice 1: Database Migration, Scoped Uniqueness & Model Invariants

### Goal
Establish the relational schema for parent-child category relationships, adjust name
uniqueness to be scoped to `(user_id, parent_category_id)` so different parents can have
children with identical names (e.g. `"SUPPLIES"`), implement model hierarchy methods, and
add comprehensive model specs.

### Detailed Steps
1. **Database Migration**:
   - Add `parent_category_id` to `categories` as nullable `bigint REFERENCES categories(id) ON DELETE RESTRICT`.
   - Add index `index_categories_on_parent_category_id`.
   - Add check constraint `categories_no_self_parent` enforcing `parent_category_id IS NULL OR parent_category_id <> id`.
   - Replace unique index `index_category_name_on_composite_key` with:
     ```sql
     DROP INDEX index_category_name_on_composite_key;
     CREATE UNIQUE INDEX index_categories_on_user_id_parent_and_name
       ON categories (user_id, parent_category_id, category_name) NULLS NOT DISTINCT;
     ```
2. **Category Model (`app/models/category.rb`)**:
   - Associations:
     - `belongs_to :parent_category, class_name: "Category", optional: true`
     - `has_many :subcategories, class_name: "Category", foreign_key: :parent_category_id, dependent: :restrict_with_error, inverse_of: :parent_category`
   - Validations:
     - Update name uniqueness:
       `validates :category_name, presence: true, uniqueness: { scope: %i[user_id parent_category_id] }`
     - Depth limit validation:
       A category cannot have a parent if that parent already has a parent (depth limit = 1).
       A category cannot be assigned a parent if it already has subcategories.
     - Same user ownership validation:
       `parent_category.user_id == user_id`.
     - Built-in category isolation:
       Built-in categories cannot have a parent and cannot be parents.
   - Convenience & Hierarchy Methods:
     - `parent?`: `subcategories.any?` (or loaded check).
     - `subcategory?` / `child?`: `parent_category_id.present?`.
     - `standalone?`: `!parent? && !subcategory?`.
     - `subtree_ids`: `[id] + subcategory_ids` (useful for queries and filters).
     - Rollup metrics:
       - `rollup_card_transactions_count`: `card_transactions_count + subcategories.sum(:card_transactions_count)`.
       - `rollup_card_transactions_total`: `card_transactions_total + subcategories.sum(:card_transactions_total)`.
       - `rollup_cash_transactions_count`: `cash_transactions_count + subcategories.sum(:cash_transactions_count)`.
       - `rollup_cash_transactions_total`: `cash_transactions_total + subcategories.sum(:cash_transactions_total)`.
   - Scopes:
     - `scope :top_level, -> { where(parent_category_id: nil) }`
     - `scope :subcategories, -> { where.not(parent_category_id: nil) }`
3. **Factories & Model Specs**:
   - Update `spec/factories/categories.rb`:
     - Trait `:parent_category` and trait `:child_category`.
   - Update `spec/models/category_spec.rb`:
     - Test scoped uniqueness: two children under different parents can have the same name; two children under the same parent cannot; two top-level categories cannot.
     - Test self-parent rejection.
     - Test depth-limit rejection (grandchild parenting).
     - Test cross-user parent rejection.
     - Test built-in parenting rejection.
     - Test direct transactions on parents are valid.
     - Test `subtree_ids` and roll-up calculations.

### Primary Touchpoints
- `db/migrate/*_add_parent_category_id_to_categories.rb`
- `app/models/category.rb`
- `spec/factories/categories.rb`
- `spec/models/category_spec.rb`

### Acceptance Criteria
- Migration applies and rolls back cleanly.
- `HSH -> SUPPLIES` and `ASSETS -> SUPPLIES` can coexist for the same user without validation errors.
- Self-parenting and grandchildren are rejected by model validations and database constraints.
- Parent categories can have direct transactions.

---

## Slice 2: Category Form & Parent Selection

### Goal
Update category creation and editing flows in `CategoriesController` and `Views::Categories::Form`
so users can choose an optional parent category and input clean child category names.

### Detailed Steps
1. **Controller (`app/controllers/categories_controller.rb`)**:
   - Permit `:parent_category_id` in `category_params`.
   - Prepare `@parent_categories` collection for forms:
     - `current_user.custom_categories.top_level.active.order(:category_name)`.
     - Exclude `@category.id` when persisted.
2. **Form View (`app/views/categories/form.rb`)**:
   - Add parent category selector:
     - Label: `"Group / Parent Category"`
     - Select input for `parent_category_id` with blank option `"None (Standalone / Top-Level Category)"`.
     - If `@category.parent?`, disable the parent category dropdown with an informative message:
       `"This category has subcategories and cannot have a parent."`
   - Pre-fill parent category if `params[:parent_category_id]` is passed to `new`.
3. **Translations**:
   - Add locale keys in `config/locales/` for parent category field label, hints, and scoped validation errors in English and `pt-BR`.
4. **Request Specs (`spec/requests/categories_spec.rb`)**:
   - Test creating a subcategory under an existing parent.
   - Test creating two subcategories with the same name under different parents.
   - Test updating a subcategory to change or remove its parent.

### Primary Touchpoints
- `app/controllers/categories_controller.rb`
- `app/views/categories/form.rb`
- `app/views/categories/new.rb`
- `app/views/categories/edit.rb`
- `config/locales/models/category.yml`
- `config/locales/views/categories.yml`
- `spec/requests/categories_spec.rb`

### Acceptance Criteria
- Category form supports selecting an eligible parent category.
- Subcategory successfully saves with clean name (e.g. `"LABOUR"` under `"HSH"`).
- Duplicate names under the same parent show friendly validation errors.

---

## Slice 3: Compound Badge Visual & Hierarchical Index

### Goal
Implement the compound badge visual `[ HSH [ LABOUR ] ]` in `Components::CategoryBadge` and
render categories in a clean grouped layout on desktop and mobile indexes with roll-up metrics.

### Detailed Steps
1. **Compound Category Badge (`app/components/category_badge.rb`)**:
   - For standalone or parent categories:
     - Render standard badge: `[ HSH ]`.
   - For child categories:
     - Render compound/nested badge: `[ HSH [ LABOUR ] ]`.
     - Outer wrapper uses parent styling/name, inner element displays the child category styling and name.
   - Update component specs in `spec/components/category_badge_spec.rb`.
2. **Desktop Index View (`app/views/categories/index.rb` & `category.rb`)**:
   - Group subcategories directly beneath their parent category.
   - Parent row:
     - Displays parent badge `[ HSH ]`.
     - Displays roll-up counts and totals (parent direct + all subcategories).
     - Provides a `+ Subcategory` button linking to `new_category_path(parent_category_id: category.id)`.
   - Subcategory row:
     - Visual indentation (`ml-6` / `pl-4` border-l).
     - Displays compound badge `[ HSH [ LABOUR ] ]`.
     - Displays individual transaction count and total.
3. **Mobile Index View (`app/views/categories/category.rb`)**:
   - Parent card with roll-up totals and subcategories count badge.
   - Indented child category cards directly below the parent.
4. **Request Specs (`spec/requests/categories_spec.rb`)**:
   - Verify desktop and mobile grouped rendering.
   - Verify roll-up totals on parent rows.

### Primary Touchpoints
- `app/components/category_badge.rb`
- `app/views/categories/index.rb`
- `app/views/categories/category.rb`
- `spec/components/category_badge_spec.rb`
- `spec/requests/categories_spec.rb`

### Acceptance Criteria
- Child categories display as `[ HSH [ LABOUR ] ]`.
- Index displays parents and children grouped together.
- Parent rows display aggregated roll-up totals.

---

## Slice 4: Transaction Form Category Selection & Hierarchical Filtering

### Goal
Update category selection in transaction forms (`CashTransaction`, `CardTransaction`, `Budget`)
so parent and child categories are both selectable, and update transaction filters so filtering
by a parent category includes all of its subcategories.

### Detailed Steps
1. **Context Helper (`app/helpers/context_helper.rb`)**:
   - Update `set_categories`:
     - Load active categories.
     - For child categories: label as `HSH / LABOUR`, with alias token including parent name for KAKASHI-18 search ranking.
     - For parent categories: label as `HSH` (selectable!).
2. **Combobox (`Views::Shared::SingleSelectCombobox`)**:
   - Ensure typing `"HSH"` matches both `"HSH"` and all its children (`"HSH / LABOUR"`, `"HSH / SUPPLIES"`).
3. **Hierarchical Filtering**:
   - When filtering by `category_id` in transaction search / ledger / reports:
     - Check if selected category has subcategories (`category.parent?`).
     - If parent: query matches `category.subtree_ids` (`[parent.id] + subcategory_ids`).
     - If child or standalone: query matches `category.id` specifically.
4. **Request Specs (`spec/requests/cash_transactions_spec.rb`, `spec/requests/card_transactions_spec.rb`)**:
   - Test creating a transaction with a parent category.
   - Test creating a transaction with a subcategory.
   - Test search filter: filtering by parent returns parent transactions AND subcategory transactions.

### Primary Touchpoints
- `app/helpers/context_helper.rb`
- `app/views/shared/single_select_combobox.rb`
- `app/services/search/` (or transaction query scopes)
- `spec/requests/cash_transactions_spec.rb`
- `spec/requests/card_transactions_spec.rb`

### Acceptance Criteria
- Parent and child categories are both selectable in transaction forms.
- Searching by parent name matches the parent and all of its subcategories.
- Filtering by parent category selects transactions across the entire category family.

---

## Slice 5: Category Merges, Allocation Mutations & Status Cascade

### Goal
Integrate category hierarchy with `CategoryMerges::Planner`, `AllocationMutations::CategoryPlanner`,
and active/inactive status cascading.

### Detailed Steps
1. **Category Merges (`app/services/category_merges/planner.rb`)**:
   - Merging into a parent category: Allowed (transactions are transferred to the parent).
   - Merging a parent category with subcategories: Blocked with conflict `:source_has_children`
     (user must delete or re-parent children first).
   - Update specs in `spec/services/category_merges/planner_spec.rb`.
2. **Allocation Mutations (`app/services/allocation_mutations/category_planner.rb`)**:
   - Both parent and child categories are valid allocation destinations.
3. **Active/Inactive Status Cascade (`app/models/category.rb`)**:
   - When a parent category is updated to `active: false`, cascade `update_all(active: false)` to its `subcategories`.
   - Validation on child: cannot be saved with `active: true` if `parent_category.active == false`.
4. **Audit and Rollback Adapter (`app/services/audit/rollback/adapters/category.rb`)**:
   - Verify `parent_category_id` is tracked on destroy/rollback.

### Primary Touchpoints
- `app/services/category_merges/planner.rb`
- `app/models/category.rb`
- `app/services/audit/rollback/adapters/category.rb`
- `spec/services/category_merges/planner_spec.rb`

### Acceptance Criteria
- Merging into a parent category works seamlessly.
- Merging a parent with children is blocked with a clear conflict message.
- Deactivating a parent deactivates all of its subcategories.

---

## Slice 6: Regression Verification, CI & Code Cleanliness

### Goal
Run full test suite, ERB lint, RuboCop, and security audits to ensure zero regressions.

### Detailed Steps
1. Run `bin/rubocop -A` across all files.
2. Run full test suite:
   - `bin/rspec spec/models/category_spec.rb spec/models/category_transaction_spec.rb`
   - `bin/rspec spec/requests/categories_spec.rb spec/requests/cash_transactions_spec.rb spec/requests/card_transactions_spec.rb`
   - `bin/rspec spec/components/category_badge_spec.rb`
   - `bin/rspec spec/services/category_merges/`
3. Run `bin/ci`.

### Acceptance Criteria
- 0 RuboCop offenses.
- All tests pass cleanly.
