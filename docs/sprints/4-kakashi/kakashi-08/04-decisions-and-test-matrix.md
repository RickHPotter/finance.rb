# KAKASHI-08 Decisions and Test Matrix

## Locked Decisions

### D1. Which versioning library is used?

PaperTrail 17 with a custom `AuditVersion`. It supports the application's Rails 8.1
and Ruby 4 stack, reification, changesets, custom metadata, and PostgreSQL JSONB.

### D2. Is historical data backfilled?

No. Auditing starts at deployment. Existing records receive their first version only
when a later create/update/destroy lifecycle event can be observed truthfully.

### D3. How long is history retained?

Indefinitely. Audit tables are append-only and no application retention purge exists.

### D4. Who can read history?

Admins can read all users and contexts. Non-admin users can read only versions whose
stored `owner_id` matches them. Access is based on immutable version ownership rather
than current live associations.

### D5. Who can roll back?

Admins only. Ordinary users receive read-only history.

### D6. What is the rollback unit?

One complete operation. Partial record rollback from a multi-record operation is not
supported.

### D7. Does rollback rewrite history?

No. It creates a new compensating operation and new versions linked to the original.

### D8. How are synchronous generated changes grouped?

They reuse the initiating operation ID and declare a more specific immediate mutation
source. Later jobs create a child operation with a new ID.

### D9. What happens when ownership cannot be resolved?

The financial mutation fails. An ownerless financial version is not accepted.

### D10. Are audit rows allowed to change?

No. Active Record guards and PostgreSQL triggers reject updates and deletes.

### D11. What payload format is used?

PostgreSQL JSONB for both full pre-change object and changeset. YAML is not used.

### D12. Are derived values restored from versions?

No. Declared counters, totals, balances, and ordering caches are recalculated through
canonical services after compensation.

### D13. How are direct SQL writes handled?

Every in-scope callback bypass is replaced with audited model writes or wrapped by an
explicit bulk audit service that captures immutable before/after versions in the same
transaction. Unclassified bypasses block model-family rollout.

### D14. Can conflicts be forced through?

No. Current state must match the original operation's expected after state. Resolve or
roll back later changes first and request a new preview.

### D15. Can a rollback itself be rolled back?

Not in V1. Its history remains visible, but the preview registry rejects it as an
unsupported target.

### D16. Does read access reveal the other side of a shared operation?

Only to admins. An ordinary user sees their owned versions without values or existence
details from versions owned by another user.

## Audit Storage Matrix

| Scenario | Expected result |
| --- | --- |
| create audited record | create version with owner, context, operation, source, and changeset |
| update audited record | pre-change object and before/after changes stored |
| destroy audited record | version remains queryable after live row disappears |
| update existing pre-rollout record | first version captures truthful pre-change state; no fake create |
| untouched pre-rollout record | no versions |
| business validation fails | no operation or version |
| outer DB transaction rolls back | operation and versions roll back |
| version insert fails | business mutation rolls back |
| no-op save | no operation or version |
| audit row update/delete through model | rejected |
| audit row update/delete through SQL | rejected by PostgreSQL |
| JSONB scalar/date/null values | round trip without YAML coercion |
| oversized payload | visible failure; no truncated or partial history |

## Operation Context Matrix

| Scenario | Expected result |
| --- | --- |
| normal controller mutation | actor, selected context, request ID, and `web` source captured |
| nested projection callback | same operation ID; `projection_sync` mutation source |
| shared synchronous update | same operation ID; each version retains its own owner/context |
| actionable message apply | receiver-owned operation linked to sender cause when available |
| import batch | bounded import metadata and explicit import source |
| admin repair | admin actor and `admin_repair` source |
| background job | new operation ID with parent operation ID |
| console wrapper | explicit console source and optional actor |
| unwrapped mutation | unknown source, never fabricated web actor |
| concurrent requests | isolated operation/actor/source state |
| job followed by another job | no CurrentAttributes leakage |

## Ownership and Authorization Matrix

| Scenario | Admin | Owning user | Other user |
| --- | --- | --- | --- |
| live owned record history | visible | visible | hidden |
| destroyed owned record history | visible | visible | hidden |
| global operation index | all rows | owned rows only | owned rows only |
| mixed-owner operation detail | complete | owned subset only | owned subset only |
| raw changeset | complete | owned versions only | hidden |
| rollback preview/apply | allowed when safe | hidden/denied | hidden/denied |
| record with deactivated owner | visible | visible when authenticated ownership still matches | hidden |

Authorization tests must assert response body non-disclosure, not only status. Hidden
versions must not contribute names, prices, counts, filter options, or pagination totals.

## Model Coverage Matrix

| Family | Ownership source | Direct-SQL gate | Rollback adapter |
| --- | --- | --- | --- |
| cash/card transaction | direct user/context | controller, import, projection writes | required |
| cash/card installment STI | parent transaction | count, paid-state, deletion writes | required |
| category allocation | polymorphic transactable | bulk/category transfer paths | required |
| entity allocation | polymorphic transactable | exchange/status repair paths | required |
| exchange | entity transactable | projection rebuild and unlink paths | required |
| reference | user card plus direct context | merge/resynchronization writes | required |
| user card | direct user | totals and reference-date sync | required |
| user bank account | direct user | totals and context purge | required |
| budget | direct user/context | bulk budget updates | required |
| subscription | direct user/context | price synchronization | required |
| investment | direct user/context | Piggy Bank profit synchronization | required |
| Piggy Bank | source/return transaction | projection link writes | required |

"Required" means the family must have an adapter before operations containing it are
rollbackable. Audit read coverage may ship earlier.

## Callback-Bypass Matrix

| Write mechanism | Expected treatment |
| --- | --- |
| `update!` / `save!` | PaperTrail callback in same transaction |
| `destroy!` | PaperTrail destroy version in same transaction |
| `update_column(s)` | replace or explicit bulk audit wrapper |
| `update_all` | capture per-record before/after versions or replace |
| `delete_all` | capture pre-destroy versions before deletion or replace |
| `insert_all` | explicit create versions with ownership in same transaction |
| counter/touch cache | skip declared derived attributes; avoid noisy versions |
| raw SQL | prohibited for audited attributes without explicit wrapper |

## History Surface Matrix

| Scenario | Expected result |
| --- | --- |
| operation index | paginated newest-first list with stable filters |
| operation detail | ordered versions grouped by record family |
| record timeline | chronological versions across operations |
| human-readable view | translated attributes and formatted money/date/booleans |
| raw disclosure | authorized JSON, collapsed by default |
| destroyed record | snapshot label, type/ID, operation, actor, and changes remain visible |
| missing live actor/context | historical IDs remain visible without error |
| request ID filter | exact indexed lookup |
| owner/context/source/date filters | scoped before pagination |
| empty result | no data leakage through counts or facet options |

## Rollback Preview Matrix

| Scenario | Expected result |
| --- | --- |
| unchanged update operation | preview proposes restore of before values |
| unchanged create operation | preview proposes dependency-safe destruction |
| unchanged destroy operation | preview proposes dependency-safe recreation |
| multiple versions for one record | one net compensation row |
| create then destroy in one operation | visible no-op compensation |
| current attribute diverged | conflicted; apply disabled |
| expected live row missing | conflicted |
| expected destroyed row recreated later | conflicted |
| later dependent exists | conflicted or prohibited |
| unsupported model family | entire operation read-only |
| paid history involved | confirmation or prohibition shown |
| repeated unchanged preview | same digest |
| preview by non-admin | not found/denied without operation disclosure |

## Rollback Apply Matrix

| Scenario | Expected result |
| --- | --- |
| valid unchanged digest | one atomic compensating operation |
| stale digest | rejected; no business versions |
| concurrent current-state change | rejected after lock/re-preview |
| one adapter validation fails | all compensation rolls back |
| paid confirmation missing | rejected |
| prohibited financial reversal | rejected even for admin |
| duplicate apply request | original result returned; no second compensation |
| successful compensation | original history untouched; rollback linked and versioned |
| unexpected exception | no partial records/versions; failed attempt recorded |
| recalculation failure | complete rollback |
| rollback of rollback target | read-only in V1 |

## Performance and Operations Matrix

| Scenario | Expected result |
| --- | --- |
| ordinary single-record update | bounded version insert overhead measured |
| projection-heavy transaction | one operation with expected version count, no duplicates |
| history index | metadata indexes used; JSON payload not loaded until needed |
| large operation detail | paginated or chunked without unbounded rendering |
| indefinite retention | table/index size metrics exposed for health monitoring |
| test suite | audit specs opt in deliberately without leaking state |
| production deploy | migrations and triggers applied before model coverage is enabled |

## Blocking Decisions

There are no known blocking product decisions. Rollback authorization is admin-only;
ordinary users receive ownership-scoped read history.
