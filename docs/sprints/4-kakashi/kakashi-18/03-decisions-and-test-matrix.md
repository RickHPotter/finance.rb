# KAKASHI-18 Decisions and Test Matrix

## Locked Product Decisions

### D1 — Ranking is client-side only

The combobox controller handles all tier computation and DOM reordering. No
server round trip is needed for ranking. The server renders options in localized
alphabetical order; the client re-sorts during live search.

### D2 — Normalization strips diacritics and case; punctuation is preserved

`normalize()` applies NFKD + combining-mark removal + lowercase + whitespace
collapse. Punctuation characters are left intact in V1. The same function is
applied to both the query and every item label.

### D3 — Aliases are pre-normalized at render time

`data-alias` values written by Ruby helpers are already normalized (downcased,
diacritics stripped). The client reads them directly without re-normalizing.

### D4 — Alias tier cannot outrank a primary-label tier

An item whose alias matches at tier 3 (word-start) is placed below an item
whose primary label matches at tier 2 (starts-with), even if the alias provides
a closer match. Aliases supplement discovery; they do not reweight primary
labels.

### D5 — Category merge is all-or-nothing in V1

There is no eligible-only mode for category merges. If any structural conflict
exists, apply is unavailable. The user must resolve conflicts manually before
the merge can proceed.

### D6 — Entity merge supports eligible-only when independence is guaranteed

An eligible-only apply option is offered only when every conflict row is
structurally independent from every eligible row. Independence is determined by
`AllocationMutations::IndependenceClassifier` (reused from KAKASHI-16).

### D7 — Merge controllers follow the KAKASHI-16 preview/apply split

Category: `CategoryMergePreviewsController` + `CategoryMergesController`.
Entity: `EntityMergePreviewsController` + `EntityMergesController`.
This separates the read-only plan from the write path and makes token validation
explicit at the apply boundary.

### D8 — Source category is destroyed only after all rows are remapped or collapsed

The destroy call is the final write inside the database transaction. If any step
before it fails, the source is left intact and the transaction rolls back.

### D9 — Source entity is destroyed only when no join rows remain

In strict mode: source is destroyed after all rows are remapped/collapsed (zero
conflicts guarantee this). In eligible-only mode: source is destroyed only if
the eligible subset leaves zero remaining rows. Otherwise, source survives and
the audit operation records the remaining row count.

### D10 — Merge entry point is a row action on the index; not on the show page

The show-page action set belongs to KAKASHI-17 scope. KAKASHI-18 adds only the
index row action.

### D11 — Built-in categories and built-in entities cannot be merged in either direction

The merge trigger is hidden in the UI and enforced server-side for records where
`built_in? == true`.

### D12 — Friend-backed entity merges are allowed only when both share the same entity_user_id

Cross-user friend merges are always a hard conflict, enforced by the planner and
the apply service.

### D13 — No schema changes required

The merge feature remaps existing join rows and destroys master records using
the existing schema. No new columns or tables are introduced.

### D14 — Locale keys for conflict reasons follow the AllocationMutations pattern

Conflict reason codes (e.g. `:payer_entity`, `:cross_user_friend_entity`) are
resolved through `I18n.t(...)` under namespaces consistent with existing
KAKASHI-16 locale files.

### D15 — RuboCop autocorrect is run after each slice

`bin/rubocop -A` is the final step of each slice before the slice is considered
complete.

---

## Test Matrix

### Part 1 — Search Ranking

#### Unit: `normalize()` helper

| Scenario | Expected |
|----------|----------|
| ASCII lowercase | unchanged |
| ASCII uppercase | lowercased |
| String with diacritics (`"São Paulo"`) | `"sao paulo"` |
| Multiple consecutive spaces | collapsed to one |
| Leading and trailing whitespace | trimmed |
| Empty string | `""` |
| Punctuation (`"R$ 1,200"`) | unchanged (`"r$ 1,200"`) |

#### Behaviour: `filterItems` ranking order

| Query | Items | Expected order |
|-------|-------|----------------|
| `"sale"` | `SALE`, `RESALE`, `WHOLESALE` | `SALE` (tier 1), `RESALE` (tier 4), `WHOLESALE` (tier 4) |
| `"ban"` | `Banco Bradesco`, `Itaú Banco`, `Santander` | `Banco Bradesco` (tier 2), `Itaú Banco` (tier 3), `Santander` hidden |
| `"nu"` | `Nubank`, `Banco do Nordeste`, `Santander` | `Nubank` (tier 2), `Banco do Nordeste` hidden (no match), `Santander` hidden |
| `"sao"` | `São Paulo`, `Banco Santo` | `São Paulo` (tier 2), `Banco Santo` (tier 3 — word `Santo`) |
| `""` (empty) | any items | no re-sort; existing `reorderItems` governs |

#### Alias: UserBankAccount combobox

| Query | Primary label | Alias | Shown? | Tier |
|-------|--------------|-------|--------|------|
| `"4567"` | `Nubank Checking` | `"nubank 4567"` | yes | alias-boosted |
| `"nu"` | `Nubank Checking` | `"nubank 4567"` | yes | tier 2 (primary label starts-with) |
| `"xyz"` | `Nubank Checking` | `"nubank 4567"` | no | hidden |
| `"4567"` | `Nubank 4567` (primary contains suffix) | `"nubank 4567"` | yes | tier 4 (primary) beats tier 3 (alias) |

#### Invariants

| Invariant | Verified by |
|-----------|-------------|
| Permanently hidden items remain hidden regardless of alias | `filterItems` test |
| Empty-state shows when ranked set is empty | existing empty-state test |
| Keyboard navigation follows ranked visible list | existing arrow-key test |
| `reorderItems` not called during active search | `filterItems` unit test |

---

### Part 2 — Category Merge Planner

#### `CategoryMerges::Planner`

| Scenario | Source | Destination | Expected plan |
|----------|--------|-------------|---------------|
| Same record | category A | category A | `apply_available? false`, no rows planned |
| Built-in source | built-in category | custom category | `apply_available? false`, conflict: `:built_in_source` |
| Built-in destination | custom category | built-in category | `apply_available? false`, conflict: `:built_in_destination` |
| Family conflict | Exchange-family category | custom category | `apply_available? false`, conflict: `:family_conflict` |
| Clean transfer | category A (3 CT rows) | category B (0 CT rows) | 3 `transfer_rows`, 0 conflicts |
| Collapse duplicate | category A (3 CT rows, 1 already on destination) | category B | 2 `transfer_rows`, 1 `collapse_row` |
| Subscription-owned row | category A (1 CT, 1 subscription CT) | category B | 1 `transfer_row`, 1 conflict: `:subscription_owned` |

#### `CategoryMerges::Apply`

| Scenario | Expected result |
|----------|----------------|
| Valid token, zero conflicts | source destroyed, destination counts refreshed, budget recomputed, audit created |
| Stale token (fingerprint changed) | `StalePlanError`, no writes committed |
| Expired token (> 15 min) | `StalePlanError`, no writes committed |
| Wrong actor in token | rejected (unauthorized) |
| Downstream validation fails (family conflict introduced under lock) | rollback, source intact |
| Budget recompute after BudgetCategory remap | budget matching/remaining updated |

---

### Part 2 — Category Merge Requests

| Scenario | Request | Expected response |
|----------|---------|-------------------|
| Guest access | POST merge_preview | redirect to login |
| Wrong user's category | POST merge | 404 |
| Valid preview | POST merge_preview (Turbo) | replace frame with preview summary |
| Preview — built-in destination selected | POST merge_preview | preview shows conflict, apply disabled |
| Apply — valid token | POST merge (Turbo) | Drive visit to index, success flash |
| Apply — stale token | POST merge (Turbo) | replace frame with staleness error |
| Non-Turbo apply | POST merge | 303 redirect to index |
| Apply — no destination param | POST merge_preview | 422 |

---

### Part 3 — Entity Merge Planner

#### `EntityMerges::Planner`

| Scenario | Expected |
|----------|----------|
| Same record | `apply_available? false`, no rows |
| Built-in source | conflict: `:built_in_entity` |
| Friend-backed source, destination different user | conflict: `:cross_user_friend_entity` |
| Friend-backed source and destination, same `entity_user_id` | eligible transfer |
| Payer source row | conflict: `:payer_entity` |
| Monetary source row (`price != 0`) | conflict: `:monetary_entity` |
| Source row with exchanges | conflict: `:exchange_entity` |
| Piggy Bank shared entity | conflict: `:piggy_bank_entity` |
| Both entities on same transaction, both non-neutral | conflict: `:same_transaction_conflict` |
| All rows neutral, destination absent | all rows `transfer_rows` |
| One neutral row, destination already on same transaction (neutral) | `collapse_rows` |
| Mixed: 2 neutral transferable + 1 payer conflict | `eligible_only_available? true` (if independent) |
| Mixed: neutral transferable shares transaction with payer conflict | `eligible_only_available? false` |

#### `EntityMerges::Apply` — Strict Mode

| Scenario | Expected |
|----------|----------|
| Valid token, zero conflicts | source destroyed, counts refreshed, audit created |
| Stale token | `StalePlanError`, rollback |
| Conflict exists | rejected before writes |

#### `EntityMerges::Apply` — Eligible-Only Mode

| Scenario | Expected |
|----------|----------|
| 2 eligible + 1 independent conflict | 2 rows transferred, source not destroyed (1 conflict row remains), audit records remaining count |
| 0 eligible + 1 conflict | `apply_available? false`, no apply offered |
| Eligible rows transferred, 0 remaining | source destroyed |
| Independence check fails under lock (conflict now linked to eligible row) | `StalePlanError`, rollback |

---

### Part 3 — Entity Merge Requests

Same structure as category merge requests, plus:

| Scenario | Request | Expected |
|----------|---------|----------|
| Eligible-only mode | POST merge (mode: eligible_only, Turbo) | eligible rows applied, source conditionally destroyed, drive visit |
| Friend-backed source → same-user destination | POST merge | applies correctly |
| Friend-backed source → different-user destination | POST merge | conflict, no writes |

---

## Coverage Requirements

All specs run under `spec/services/category_merges/`,
`spec/services/entity_merges/`, `spec/requests/category_merge_previews_spec.rb`,
`spec/requests/category_merges_spec.rb`,
`spec/requests/entity_merge_previews_spec.rb`, and
`spec/requests/entity_merges_spec.rb`.

JavaScript ranking behaviour is verified through focused unit tests in
`spec/javascript/combobox_controller_spec.js` (or equivalent test file for the
project's JS test runner).

CI path: request and service specs are in the CI-required subset
(`spec/requests`, `spec/services`). JavaScript tests run in the `yarn test`
step if configured.
