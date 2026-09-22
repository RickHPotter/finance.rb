# NARUTO-01 Category Hierarchy: Decisions and Test Matrix

## Resolved Product Decisions

### D1. What is the maximum nesting depth?
**Decision**: Strictly two levels (parent → child). A child category cannot have children of its own.
Two levels keep daily transaction entry and reporting simple and predictable without introducing
deep recursive navigation.

### D2. Can parent categories receive transactions directly?
**Decision**: Yes! Standalone or one-time transactions that are too niche to warrant a dedicated
subcategory can be assigned directly to the parent category (e.g. tagging an unusual item directly
to `"HSH"` or `"ASSETS"`). This also makes introducing children to an existing category completely
seamless without forcing upfront reclassification of historical transactions.

### D3. How are child categories named?
**Decision**: Clean names without redundant parent prefixes. For parent `"HSH"`, child categories
are named `"SUPPLIES"`, `"LAND & PROPERTY"`, and `"LABOUR"` (not `"HSH - LABOUR"`).

### D4. How is category name uniqueness enforced?
**Decision**: Name uniqueness is scoped to `(user_id, parent_category_id)` with `NULLS NOT DISTINCT`.
This allows two completely different parent categories to each have a child with the same name
(e.g. `"HSH -> SUPPLIES"` and `"ASSETS -> SUPPLIES"`), while preventing duplicates under the same parent
or among top-level categories.

### D5. How are child categories visually presented?
**Decision**: Compound badge visual: `[ HSH [ LABOUR ] ]`.
- Top-level or standalone categories display as `[ HSH ]`.
- Child categories display with the parent category context wrapping the child name.
This visual representation can be tuned in CSS/components and immediately communicates full context.

### D6. How are categories displayed and ranked in transaction comboboxes?
**Decision**: Both parent categories and child categories are selectable in transaction forms
(`CashTransaction`, `CardTransaction`, `Budget`). Child categories carry their parent category's name
as a searchable alias token, so searching for `"HSH"` in a combobox matches both `"HSH"` and all of its
subcategories (`"HSH / LABOUR"`, `"HSH / SUPPLIES"`).

### D7. How does hierarchical category filtering work?
**Decision**:
- **Filtering by a Child Category**: Selects transactions tagged specifically to that child category.
- **Filtering by a Parent Category**: Selects transactions tagged to the parent **plus** all transactions
  tagged to any of its subcategories (`category.subtree_ids`).

### D8. How are parent category totals displayed on the index?
**Decision**: Parent category rows on `/categories` display the **roll-up sum** (direct parent transactions
plus all subcategories' transactions) for card count, card total, cash count, and cash total.

### D9. How do Category Merges interact with hierarchy?
**Decision**:
1. Merging into a parent category is permitted (transactions are transferred to the parent).
2. Merging a parent category that has active subcategories is blocked with conflict `:source_has_children`
   (user must delete or re-parent children first to avoid orphaning).

### D10. What happens when a parent category is deactivated?
**Decision**: Deactivation cascades: setting a parent category's `active: false` updates all its
subcategories to `active: false`. Furthermore, a model validation prohibits a subcategory from being
marked `active: true` while its parent category is inactive.

### D11. Can a parent category be deleted while it has children?
**Decision**: No. `dependent: :restrict_with_error` and database `ON DELETE RESTRICT` prevent
deleting a parent category that owns subcategories.

---

## Test Matrix

### 1. Model & Unit Tests (`spec/models/`)

| File | Scenario | Expected Outcome |
|---|---|---|
| `category_spec.rb` | Valid standalone category (nil parent) | Passes validation |
| `category_spec.rb` | Valid subcategory pointing to top-level category | Passes validation |
| `category_spec.rb` | Two subcategories with same name under different parents | Both valid and persistable |
| `category_spec.rb` | Two subcategories with same name under same parent | Fails validation with duplicate name error |
| `category_spec.rb` | Two top-level categories with same name | Fails validation with duplicate name error |
| `category_spec.rb` | Direct transactions on parent category | Fully permitted and valid |
| `category_spec.rb` | Adding subcategory to category with existing transactions | Fully permitted and valid |
| `category_spec.rb` | Self-parenting (`parent_category_id = id`) | Fails validation and DB check constraint |
| `category_spec.rb` | Grandchild parenting (parent already has parent) | Fails validation with `:cannot_be_child_of_child` |
| `category_spec.rb` | Assigning parent to category that has subcategories | Fails validation with `:cannot_have_parent_when_has_children` |
| `category_spec.rb` | Parent belongs to different user | Fails validation with `:must_belong_to_same_user` |
| `category_spec.rb` | Built-in category assigned as parent or child | Fails validation |
| `category_spec.rb` | Destroying parent category with subcategories | Destruction blocked with error |
| `category_spec.rb` | Subcategory activated while parent is inactive | Fails validation |
| `category_spec.rb` | Deactivating parent cascades to subcategories | All subcategories updated to `active: false` |
| `category_spec.rb` | `subtree_ids` helper | Returns `[id] + subcategory_ids` |
| `category_spec.rb` | `rollup_card_transactions_total/count` | Returns parent direct + subcategories card transactions |
| `category_spec.rb` | `rollup_cash_transactions_total/count` | Returns parent direct + subcategories cash transactions |

### 2. Component Tests (`spec/components/`)

| File | Scenario | Expected Outcome |
|---|---|---|
| `category_badge_spec.rb` | Standalone category | Renders standard badge `[ HSH ]` |
| `category_badge_spec.rb` | Parent category | Renders standard badge `[ HSH ]` |
| `category_badge_spec.rb` | Subcategory | Renders compound visual `[ HSH [ LABOUR ] ]` |

### 3. Request & Controller Tests (`spec/requests/`)

| File | Endpoint & Action | Scenario | Expected Outcome |
|---|---|---|---|
| `categories_spec.rb` | `GET /categories` | Renders parent and child categories | Parent rendered with group badge; children indented |
| `categories_spec.rb` | `GET /categories` | Renders roll-up totals on parent row | Card/cash count and total match parent direct + children |
| `categories_spec.rb` | `GET /categories` | Mobile view | Renders grouped card layout with children |
| `categories_spec.rb` | `GET /categories/new` | Renders form | Shows parent selector with eligible top-level categories |
| `categories_spec.rb` | `POST /categories` | Creates subcategory with valid parent | Persists category with `parent_category_id`; redirects |
| `categories_spec.rb` | `POST /categories` | Same child name under different parent | Successfully creates without conflict |
| `categories_spec.rb` | `GET /categories/:id/edit`| Edits parent category with children | Parent selector is disabled with caption |
| `categories_spec.rb` | `PATCH /categories/:id` | Changes parent of subcategory | Updates `parent_category_id` successfully |
| `categories_spec.rb` | `PATCH /categories/:id` | Deactivates parent category | Deactivates parent and cascades to all subcategories |
| `categories_spec.rb` | `DELETE /categories/:id`| Destroys parent category with children | Blocked with alert, category not destroyed |
| `cash_transactions_spec.rb` | `GET /cash_transactions/new` | Category combobox rendering | Parent and child categories selectable; child has parent alias |
| `cash_transactions_spec.rb` | `POST /cash_transactions` | Creates transaction with parent category | Successfully creates transaction |
| `cash_transactions_spec.rb` | `POST /cash_transactions` | Creates transaction with subcategory | Successfully creates transaction |
| `cash_transactions_spec.rb` | `GET /cash_transactions?category_id=parent_id` | Filtering by parent category | Returns parent direct transactions AND all subcategories' transactions |
| `cash_transactions_spec.rb` | `GET /cash_transactions?category_id=child_id` | Filtering by child category | Returns only that child's transactions |

### 4. Service & Integration Tests (`spec/services/`)

| File | Service Under Test | Scenario | Expected Outcome |
|---|---|---|---|
| `category_merges/planner_spec.rb` | `CategoryMerges::Planner` | Source category has subcategories | Returns conflict `:source_has_children` |
| `category_merges/planner_spec.rb` | `CategoryMerges::Planner` | Destination category is a parent | Returns eligible plan (transactions transferred) |
| `category_merges/planner_spec.rb` | `CategoryMerges::Planner` | Source and destination are leaf categories | Returns eligible plan |
| `allocation_mutations/category_planner_spec.rb` | `AllocationMutations::CategoryPlanner` | Target is parent category | Returns eligible plan |
| `allocation_mutations/category_planner_spec.rb` | `AllocationMutations::CategoryPlanner` | Target is subcategory | Returns eligible plan |

---

## Acceptance Sign-Off Checklist
- [ ] Database migration applied with scoped unique index `(user_id, parent_category_id, category_name) NULLS NOT DISTINCT`.
- [ ] Model validations allow direct transactions on parents and allow identical child names under different parents.
- [ ] `CategoryBadge` renders compound `[ HSH [ LABOUR ] ]` visual for subcategories.
- [ ] Category form allows parent assignment and handles scoped uniqueness errors.
- [ ] Category index renders hierarchical layout with accurate roll-up sums on desktop and mobile.
- [ ] Transaction combobox allows selecting parent and child categories, ranking subcategories by parent alias.
- [ ] Filtering by parent category selects parent direct transactions plus all subcategory transactions.
- [ ] All RSpec tests pass without regression.
- [ ] `bin/rubocop -A` clean.
