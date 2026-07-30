# KAKASHI-18 Implementation Slices

## Overview

KAKASHI-18 is delivered in seven sequential slices. Each slice produces
independently reviewable work. Slices 1–3 cover search ranking; slices 4–7
cover category and entity merge.

---

## Slice 1 — Combobox Normalization Utility

**Goal:** Extract a shared normalization function and use it in `filterItems`.

### Deliverables

- Add a `normalize(str)` helper in `combobox_controller.js`:
  - NFKD decomposition
  - Strip combining diacritics
  - Lowercase
  - Collapse + trim whitespace
- Replace the existing `filterTerm.toLowerCase()` / `text.toLowerCase()` pair
  with `normalize(filterTerm)` / `normalize(text)` in `filterItems`.
- Keep the existing hide/show DOM logic intact — normalization alone is the only
  change in this slice.

### Acceptance

- `normalize("São Paulo")` === `"sao paulo"`
- `normalize("CAFÉ")` === `"cafe"`
- `normalize("  hello  world  ")` === `"hello world"`
- A search for `"sao"` still reveals `"São Paulo"` items.
- No visible behaviour change for queries with no diacritics.

---

## Slice 2 — Tiered Ranking in filterItems

**Goal:** After filtering, sort visible items into tier order instead of leaving
them in document order.

### Deliverables

- Extend `filterItems` to compute a tier score (1–5) for each visible item
  using `normalize(label)` vs `normalize(filterTerm)`.
- Re-order DOM nodes (or record indices) of visible items so lower tier numbers
  appear first.
- Within the same tier, preserve the original server-rendered order (stable
  sort).
- When the search input is empty, do not re-sort — existing `reorderItems`
  behaviour (checked items float to top) governs the empty-query state.

Tier scoring:

```
1  exact:       normalize(label) === query
2  starts-with: normalize(label).startsWith(query)
3  word-start:  normalize(label).split(/\s+/).some(w => w.startsWith(query))
4  substring:   normalize(label).includes(query)
5  (alias only — see Slice 3)
```

### Acceptance

- Searching `"sale"` ranks `SALE` (tier 1) above `RESALE` (tier 4).
- Searching `"nu"` ranks `Nubank` (tier 2) above `Banco do Nordeste` (tier 4,
  if `nordeste` contains `nu`... it does not, but the test confirms tier
  ordering is stable).
- Searching `"ban"` ranks `Banco Bradesco` (tier 2) before `Itaú Banco` (tier
  3, word-start on `banco`), before any tier-4 entries.
- Empty query: existing `reorderItems` behaviour unchanged.
- All existing keyboard navigation and empty-state tests still pass.

---

## Slice 3 — Alias Token Support

**Goal:** Allow `data-alias` on combobox items for domain-specific secondary
search tokens (UserBankAccount, UserCard).

### Deliverables

#### JavaScript

- Read `item.dataset.alias` (or `item.querySelector("input").dataset.alias`)
  during `filterItems`.
- When the primary label tier is 4 (substring) or the item is not visible at
  all, check whether the alias satisfies a higher tier.
- If the alias provides tier ≤ 3, use the alias tier as the item's effective
  score.
- The alias can never promote an item above another whose primary label already
  satisfies a lower tier number.

#### Ruby — UserBankAccount Combobox

- Add `data: { alias: "#{bank_name} #{account_suffix}" }` to the item wrapper
  when rendering `Views::UserBankAccounts::Combobox`.
- The alias is pre-normalized (downcased, stripped, no diacritics) so the
  client does not need to re-normalize.

#### Ruby — UserCard Combobox (single-select forms)

- Add `data: { alias: "#{card_brand} #{last_four}" }` when rendering card
  options in `Views::Shared::SingleSelectCombobox` for user-card contexts.
- Existing `data: { text: label }` remains unchanged.

### Acceptance

- Searching `"4242"` shows the card whose last four are `4242`, ranked at its
  alias tier.
- A card whose primary label includes `4242` still ranks higher than one whose
  alias includes `4242`.
- Category and entity comboboxes have no alias attributes and behave identically
  to Slice 2.
- Permanently hidden items (already selected in multi-select contexts) remain
  hidden regardless of alias match.

---

## Slice 4 — Category Merge Planner and Service

**Goal:** Implement the read-only merge planner and the atomic merge service
for categories.

### Deliverables

#### `CategoryMerges::Planner`

```
app/services/category_merges/planner.rb
```

- Accepts: `actor`, `context`, `source`, `destination`
- Returns: a `CategoryMerges::Plan` value object with:
  - `source`, `destination`
  - `transfer_rows`: array of join rows to remap
  - `collapse_rows`: array of join rows to destroy (destination duplicate)
  - `conflict_rows`: array of rows blocked, each with a `reason_code`
  - `apply_available?`

Handles:
- Built-in source/destination guard
- Same-record no-op guard
- Category-family conflict detection via existing allocation policy
- Subscription-owned allocation detection
- Per-join-type uniqueness pre-check

#### `CategoryMerges::Apply`

```
app/services/category_merges/apply.rb
```

- Accepts: `actor`, `context`, `request_id`, `token`
- Steps as defined in the contract (token validation → lock → replan → remap →
  collapse → validate → destroy source → refresh counters → recompute budgets →
  audit)
- Raises `CategoryMerges::StalePlanError` if eligibility changed under lock.
- Wraps everything in one `ApplicationRecord.transaction`.

#### `CategoryMerges::PreviewToken`

```
app/services/category_merges/preview_token.rb
```

- Same HMAC pattern as `AllocationMutations::PreviewToken`.
- Signs: `actor_id`, `context_id`, `source_id`, `destination_id`,
  `result_fingerprint`.
- 15-minute expiry.

### Specs

```
spec/services/category_merges/planner_spec.rb
spec/services/category_merges/apply_spec.rb
```

Covers: no-op same-record, built-in guard, cross-family block, Subscription
conflict, eligible transfer, collapse of duplicate, stale token rejection,
rollback on downstream failure, counter refresh, budget recomputation.

---

## Slice 5 — Category Merge Controllers, Routes, and Views

**Goal:** Wire the category merge planner and service into the HTTP layer and
the categories index UI.

### Deliverables

#### Routes

```ruby
resources :categories do
  member do
    post :merge_preview, to: "category_merge_previews#create"
    post :merge,         to: "category_merges#create"
  end
end
```

#### `CategoryMergePreviewsController#create`

- Loads source category from `current_user.categories`.
- Instantiates `CategoryMerges::Planner`.
- Responds to Turbo Stream: replaces `category_merge_preview_#{source.id}`
  frame with `Views::CategoryMerges::Preview`.
- Responds to HTML fallback.

#### `CategoryMergesController#create`

- Loads source category from `current_user.categories`.
- Calls `CategoryMerges::Apply`.
- On success: Turbo Drive visit to categories index (or `return_to`).
- On stale/conflict: replaces preview frame with error summary.
- On not-found/auth error: 404.
- Always appends flash notification to `:notification`.

#### `Views::CategoryMerges::Preview` (Phlex)

```
app/views/category_merges/preview.rb
```

- Destination single-select combobox (excluding source, built-ins, inactive).
- Summary counts: total, transfer, collapse, conflict.
- Conflict reason list (localized).
- `Merge and destroy` button (disabled when conflicts > 0 or destination blank).
- Preview form (POST to `merge_preview_category_path`).
- Apply form (POST to `merge_category_path`) with signed token.
- `Cancel` button.

#### `Views::Categories::Category` (row component)

- Add a `Merge` row action that targets the merge modal/frame.
- Hidden for built-in categories.

### Specs

```
spec/requests/category_merge_previews_spec.rb
spec/requests/category_merges_spec.rb
```

Covers: preview rendering, auth, not-found, apply success, stale token,
conflict block, counter refresh, budget recompute, notifications, Turbo and
non-Turbo response.

---

## Slice 6 — Entity Merge Planner and Service

**Goal:** Implement the entity merge planner and service with structural
conflict handling and eligible-only mode.

### Deliverables

#### `EntityMerges::Planner`

```
app/services/entity_merges/planner.rb
```

- Accepts: `actor`, `context`, `source`, `destination`, `mode:` (`:strict` or
  `:eligible_only`)
- Returns: `EntityMerges::Plan` value object with:
  - `transfer_rows`, `collapse_rows`, `conflict_rows` (each with `reason_code`)
  - `eligible_only_available?`
  - `apply_available?`

Conflict detection covers all seven conflict kinds defined in the contract.

Independence classifier from `AllocationMutations::IndependenceClassifier` is
reused to determine whether `eligible_only_available?` can be true.

#### `EntityMerges::Apply`

```
app/services/entity_merges/apply.rb
```

- Accepts: `actor`, `context`, `request_id`, `token`, `mode:`
- Steps as defined in the contract.
- When `mode: :eligible_only`, skips conflict rows and conditionally destroys
  source (only if no rows remain).
- Audit operation records `mode` and remaining count (if source not destroyed).

#### `EntityMerges::PreviewToken`

```
app/services/entity_merges/preview_token.rb
```

Same HMAC pattern as `CategoryMerges::PreviewToken`.

### Specs

```
spec/services/entity_merges/planner_spec.rb
spec/services/entity_merges/apply_spec.rb
```

Covers: neutral transfer, payer conflict, monetary conflict, exchange conflict,
Piggy Bank conflict, same-transaction conflict, friend-backed guard, cross-user
guard, collapse of neutral duplicate, eligible-only independence check,
eligible-only partial transfer without source destroy, stale token, rollback.

---

## Slice 7 — Entity Merge Controllers, Routes, and Views

**Goal:** Wire the entity merge planner and service into the HTTP layer and the
entities index UI.

### Deliverables

#### Routes

```ruby
resources :entities do
  member do
    post :merge_preview, to: "entity_merge_previews#create"
    post :merge,         to: "entity_merges#create"
  end
end
```

#### `EntityMergePreviewsController#create`

Mirror of `CategoryMergePreviewsController`, using `EntityMerges::Planner`.

#### `EntityMergesController#create`

Mirror of `CategoryMergesController`, using `EntityMerges::Apply`.

#### `Views::EntityMerges::Preview` (Phlex)

```
app/views/entity_merges/preview.rb
```

- Same structure as category preview.
- Additional per-conflict-kind breakdown (payer, monetary, exchange, Piggy Bank,
  same-transaction, friend).
- `Merge and destroy` button (strict mode, available only when zero conflicts).
- `Transfer eligible only` button (visible only when `eligible_only_available?`
  is true).
- Signed token hidden field (scoped to the chosen mode).

#### `Views::Entities::Entity` (row component)

- Add a `Merge` row action.
- Hidden for built-in entities and friend-backed entities.

### Specs

```
spec/requests/entity_merge_previews_spec.rb
spec/requests/entity_merges_spec.rb
```

Covers: same categories from slice 5 plus eligible-only apply, partial source
survival, friend guard, cross-user block, Turbo and non-Turbo.

---

## Cross-Slice Constraints

- RuboCop autocorrect (`bin/rubocop -A`) runs after each slice.
- Request specs are added in the same slice that introduces each controller.
- No slice introduces migrations — this feature needs no schema changes.
- Locale keys for conflict reasons and notification messages are added in the
  slice that first uses them.
- The `AllocationMutations::IndependenceClassifier` is reused (not copied) by
  the entity merge planner.
