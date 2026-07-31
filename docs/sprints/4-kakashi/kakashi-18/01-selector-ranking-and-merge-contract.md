# KAKASHI-18 Selector Ranking and Merge Contract

## Objective

Make financial selectors rank the user's intended result predictably and provide
transaction-safe category/entity consolidation directly from their indexes.

KAKASHI-18 has two independent sub-features:

1. **Search Ranking** — Apply one normalized, tiered ranking contract to all
   combobox selectors.
2. **Merge (Category and Entity)** — Add a row action that previews, transfers,
   and destroys a source master record safely.

KAKASHI-16 supplies the execution foundation (planner vocabulary, preview token,
deterministic locking, strict/eligible-only modes, audit metadata, rollback
adapters, and impact recalculation registry). KAKASHI-18 adds a separate
master-record merge/delete planner on top of that foundation.

---

## Part 1 — Search Ranking

### Current Behaviour

`combobox_controller.js#filterItems` calls `text.indexOf(filterTerm) > -1` to
decide visibility. Items are shown or hidden; their DOM order is never changed
during filtering. No normalization is applied beyond `toLowerCase()`. This means
a query like `SALE` shows both `SALE` and `RESALE` in document order, with no
preference for the closer match.

### Locked V1 Direction

#### Ranking Tiers (highest to lowest priority)

| Tier | Condition |
|------|-----------|
| 1 — Exact match | Normalized label equals normalized query |
| 2 — Starts-with | Normalized label starts with normalized query |
| 3 — Word-start | Any word inside the normalized label starts with the normalized query |
| 4 — Substring | Normalized label contains the normalized query anywhere |
| 5 — Alias-boosted | A `data-alias` token satisfies a higher tier than the primary label |

Within each tier, items are ordered by their original server-rendered position
(localized alphabetical, the same stable tie-breaker used at page load).

Alias-boosted items are shown because an alias token matches; they never appear
above an item whose primary label satisfies a higher tier.

#### Normalization Contract

A single `normalize(str)` utility applies the following steps in order:

1. Unicode NFKD decomposition (`str.normalize("NFKD")`)
2. Remove combining diacritical marks (`/\p{Mn}/u`)
3. Lowercase (`toLowerCase()`)
4. Collapse repeated whitespace, then trim

The same normalization is applied to both the search query and every item label
before any tier comparison. This makes `São Paulo` match `sao paulo`, `SAO`,
and `PAU` correctly.

Punctuation is preserved during normalization. Only diacritics and case are
stripped in V1.

#### Alias Tokens

Some combobox items carry domain-specific searchable aliases that should
improve discoverability without outranking a primary label:

- **UserBankAccount**: bank name and account number suffix (e.g. `"nubank 0042"`)
- **UserCard**: card brand and last-four digits (e.g. `"visa 1234"`)
- **Category**: no alias in V1 — category name is the only searchable label
- **Entity**: no alias in V1 — entity name is the only searchable label

Aliases are exposed through a `data-alias` attribute on the `ComboboxItem`
wrapper (or the hidden input). The ranking algorithm checks alias tokens only
after all primary-label tiers. A weak alias match (substring only) cannot bump
an item above one whose primary label matches at a higher tier.

The Ruby side adds `data: { alias: "..." }` when rendering combobox items for
UserBankAccount and UserCard. The alias string is pre-normalized at render time
so the client does not need to re-normalize it.

#### Implementation Location

Ranking lives entirely in `combobox_controller.js#filterItems`. No server round
trip is required during a live search session. The server continues to render
options in localized alphabetical order. The client re-sorts visible items into
tier order after each keypress.

When the search input is cleared, items return to their server-rendered order
(the `reorderItems`/`selectedOrder` checked-items-first logic takes over).

#### Keyboard Selection and Large Lists

Keyboard navigation (`ArrowDown`/`ArrowUp`/`Enter`/`Tab`) operates on the
filtered-and-ranked visible list. Permanently hidden items are still skipped.
The empty-state message is shown when the ranked result set is empty. No virtual
scrolling is added in V1.

---

## Part 2 — Category Merge and Destroy

### Goal

Add a row action on the categories index that lets a user select a destination
category, preview every affected record, transfer all eligible allocations from
source to destination, and remove the source category atomically.

### Merge Semantics

| Term | Meaning |
|------|---------|
| Source | The category being consumed and destroyed |
| Destination | The surviving category that absorbs source's allocations |
| Transfer | Remapping an allocation join row from source to destination |
| Collapse | Destroying a duplicate join row already pointing at destination |

### What Is Transferred

The following allocation-row types are remapped from source to destination:

- `CategoryTransaction` — `CashTransaction`
- `CategoryTransaction` — `CardTransaction`
- `CategoryTransaction` — `Investment`
- `CategoryTransaction` — `Subscription`
- `BudgetCategory`

When the destination already appears on the same owner, the source join row is
**collapsed** (destroyed) instead of remapped. This keeps the uniqueness index
on `(category_id, transactable_type, transactable_id)` intact.

### Built-in Protection

The following conditions block the merge entirely:

- Source is a built-in/system category.
- Destination is a built-in/system category.
- Source and destination belong to conflicting category families (as defined
  by the allocation policy category-family rule).
- Source equals destination (same-record no-op).

### Structural Conflicts

Category merges are all-or-nothing in V1. There is no eligible-only mode.

A structural conflict occurs when a join row cannot be remapped because:

- The resulting destination allocation would violate a category-family
  invariant on that owner.
- A Subscription-owned allocation requires a Subscription-workflow change
  rather than a generic remap.

When any structural conflict exists, the merge preview reports it but does not
offer an apply option. The user must resolve conflicts (e.g. via the normal
Subscription form) before the merge can proceed.

### Preview Contract

Preview is read-only and creates no audit operation. It returns:

- Source and destination category labels (with resolved colour badges)
- Total join rows owned by source
- Eligible-to-transfer count
- Collapse count (already-at-destination duplicates)
- Conflict count and grouped localized conflict reasons
- Representative record links
- Whether apply is available

### Apply Contract

Apply proceeds only when preview reported zero conflicts and the signed token is
valid.

Apply steps:

1. Validate signed preview token (actor, context, source ID, destination ID,
   result digest).
2. Reload and pessimistically lock source, destination, and all affected join
   rows.
3. Replan under lock; reject stale token if eligibility changed.
4. Remap eligible join rows to destination.
5. Destroy collapsed (duplicate) join rows.
6. Run final uniqueness and family-constraint validation on destination.
7. Destroy source category.
8. Refresh destination category counter columns.
9. Recompute budget matching for every budget whose `BudgetCategory` was
   remapped.
10. Write one KAKASHI-08 audit operation (source ID, destination ID, counts,
    result).
11. Return to categories index; display success notification.

If any step fails, the entire database transaction rolls back. Source category
and all join rows are left intact.

### UI Entry Point

The merge trigger is a **row action** on the categories index, placed alongside
Edit and Destroy. It opens a Turbo-framed modal containing:

1. A single-select combobox for the destination category (excludes source,
   built-in categories, and inactive categories).
2. A `Preview` button.
3. The server-rendered preview summary (counts, representative links, conflict
   reasons when present).
4. A `Merge and destroy` confirmation button (disabled until preview returns
   zero conflicts).
5. A `Cancel` button.

The merge row action is hidden for built-in categories.

### Controller Split

Following the KAKASHI-16 pattern:

- `CategoryMergePreviewsController#create` (POST) — runs the planner and
  renders the preview frame.
- `CategoryMergesController#create` (POST) — validates token and applies.

Routes:

```
POST /categories/:category_id/merge_preview  →  category_merge_previews#create
POST /categories/:category_id/merge          →  category_merges#create
```

---

## Part 3 — Entity Merge and Destroy

### Goal

Add the equivalent source-to-destination merge action for entities, with
additional structural conflict handling for `EntityTransaction` rows and
friend-backed identity protection.

### What Is Transferred

The following allocation-row types are remapped from source to destination:

- `EntityTransaction` — `CashTransaction`
- `EntityTransaction` — `CardTransaction`
- `EntityTransaction` — `Subscription`
- `BudgetEntity`

When both source and destination exist on the same owner and both are neutral
(non-payer, zero price, zero return, no exchanges), the source row is
**collapsed** (destroyed).

### Structural Conflict Cases

The following situations are reported as explicit structural conflicts:

| Conflict | Reason code |
|----------|-------------|
| Source row is a payer (`is_payer: true`) | `:payer_entity` |
| Source row has a non-zero `price` | `:monetary_entity` |
| Source row has exchanges | `:exchange_entity` |
| Source row is the Piggy Bank shared entity | `:piggy_bank_entity` |
| Both source and destination exist on the same transaction as non-neutral rows | `:same_transaction_conflict` |
| Source entity is built-in (self entity) | `:built_in_entity` |
| Source entity is friend-backed and destination represents a different user | `:cross_user_friend_entity` |

### Eligible-Only Mode

An **eligible-only** apply option is offered when:

- At least one eligible (neutral, transferable) join row exists, AND
- Every conflict row is structurally independent from every eligible row (they
  do not share the same transaction or linked structural group), AND
- Applying only the eligible subset leaves both source and destination in valid
  states.

Eligible-only mode is itself atomic and does not apply record-by-record in a
best-effort loop. When eligible-only apply is chosen, the source entity is
destroyed only if it has no remaining join rows after the partial transfer.

### Friend-Backed Merge Guard

- Merging two friend-backed entities is allowed only when both share the same
  `entity_user_id`.
- Merging a friend-backed entity into a non-friend entity (or vice versa) is
  always a hard conflict.

### Preview Contract

Same structure as category merge preview, with additional fields:

- Per-conflict-kind counts (`:payer_entity`, `:monetary_entity`, etc.)
- `eligible_only_available?` flag

### Apply Contract

Same steps as category merge apply, with the following additions:

- Step 3 also validates eligible-only mode independence when `mode:
  :eligible_only`.
- Step 5 collapses neutral duplicate destination rows.
- After step 7 (attempted destroy): if any conflict rows remain on source (in
  eligible-only mode), source is not destroyed and the audit operation records
  the remaining row count.
- Step 8 refreshes destination entity counter columns.

### Controller Split

Following the same pattern:

```
POST /entities/:entity_id/merge_preview  →  entity_merge_previews#create
POST /entities/:entity_id/merge          →  entity_merges#create
```

---

## Shared Operation Contract

### Preview Token

A short-lived HMAC digest binding:

- Actor (current user ID)
- Current context ID
- Record type (`category` or `entity`)
- Source ID
- Destination ID
- Planner result fingerprint (counts + conflict set hash)

Token expiry: 15 minutes.

### Audit (KAKASHI-08 Integration)

One apply request creates one KAKASHI-08 root audit operation with metadata:

- Action (`category_merge` or `entity_merge`)
- Source ID and label (snapshot at apply time)
- Destination ID and label
- Mode (`strict` or `eligible_only`)
- Transfer count, collapse count, conflict count
- Affected owner IDs by join type

Preview creates no audit operation. A rejected or stale apply creates no
committed financial versions.

### Recalculation

- Source and destination counter columns are refreshed after apply.
- Budget matching is recomputed for every budget whose allocation join was
  remapped.
- Financial balance recalculation is **not** run — no monetary values changed.

### Context and Authorization

- Source and destination records are loaded through `current_user` (categories
  and entities are user-owned, not context-scoped).
- Allocation join rows are validated to belong to `current_context` owners.
- An administrator cannot merge another user's records.
- Not-found and authorization errors are returned without leaking record
  existence.

### KAKASHI-15 Navigation

The merge modal/frame opens as an in-place overlay; the category/entity index
URL does not change. After a successful apply, a Turbo Drive visit refreshes the
index to its canonical URL.

---

## Explicitly Out of Scope (V1)

- Merging more than one source into a destination in one operation.
- Moving subscriptions between categories/entities through the generic merge
  path (the Subscription workflow owns its allocation set).
- Merging across users or contexts.
- Bulk-selecting multiple sources for a single-destination merge.
- Automatic deduplication of records with similar names.
- Merge history browsing beyond the KAKASHI-08 audit trail.
- Merging built-in or system-managed records of any kind.
- A merge entry point on the category/entity show page (that belongs to
  KAKASHI-17 show-page scope).
