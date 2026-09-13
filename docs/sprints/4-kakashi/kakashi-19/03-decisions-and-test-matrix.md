# KAKASHI-19 Decisions and Test Matrix

## Confirmed Decisions

### D1. Do slugs authorize access?

No. User and Entity slugs are decorative at most. Internal access uses the signed-in
owner plus an indexed Entity public ID. External access uses an active share token.

### D2. Does authorization happen only on the index request?

No. Root, cash/card indexes, search, and every lazy month endpoint independently
resolve the same access boundary.

### D3. Can an external request choose an owner, Entity, or Context by parameter?

No. The share grant resolves all three. Conflicting or extra identity parameters are
ignored or rejected; they never broaden scope.

### D4. What response distinguishes unknown, expired, revoked, or foreign access?

None. All return the same not-found surface without owner/Entity/share details.

### D5. Are internal and external financial queries separate?

No. They use one canonical ledger query and typed result contract after access has
resolved an Entity and Context. Access policy and row presentation remain explicit
and separate.

### D6. Are full transaction models safe in external views?

No. External rendering accepts an allowlisted immutable row projection. Adding a
private model attribute cannot silently add it to a public page.

### D7. Does KAKASHI-19 mutate finance records?

No. Only share lifecycle and bounded access telemetry write. Ledger reads do not edit
transactions, installments, allocations, balances, messages, or audits.

### D8. Can the old slug-only public URL remain active?

No. It may return not-found or redirect only when an independently valid share is
already present. Guessable names never retain public authority for compatibility.

The explicit `/lalas` route is the sole owner-approved exception: it is an intentional
public alias for the unique active `LALA` Entity and its owner's main Context. It uses
the hardened external ledger presentation, privacy headers, throttling, and query
contract. It fails closed if that identity is missing or ambiguous; deployments may
bind it to a stable Entity with `LALAS_ENTITY_PUBLIC_ID`.

### D9. How are duplicate allocation joins handled?

The installment is selected canonically before enrichment and appears once. Multiple
Categories or Entities cannot multiply count or amount.

### D10. What is the external cache/indexing policy?

No-store, noindex/nofollow/noarchive, strict referrer behavior, and application-level
throttling apply to HTML and fragment responses.

### D11. Does share revocation affect an already open page?

Yes. The next navigation, filter, or lazy-frame request returns the generic unavailable
surface. No nested endpoint trusts the initial page load.

### D12. Is `lalas` the permanent domain name?

No. New code uses `Ledgers`. Legacy constants/helpers exist only as bounded migration
shims and are removed when route compatibility is complete.

## Decisions Awaiting Owner Confirmation

### O1. External field allowlist

Recommended: show owner/Entity display identity, description, date/billing month,
installment position, amount, paid/pending state, and filtered totals. Hide comments,
account/card names, Categories, other Entities, references, internal IDs, and all
private chrome.

### O2. Share granularity and expiry

Recommended: one grant covers cash and card for one Entity and one Context. Expiry is
optional and defaults to no expiry; explicit revocation/rotation is always available.

### O3. Context and canonical URL

Recommended: internal ledger follows the user's active Context; each external share is
bound permanently to the Context selected at creation. Use an opaque token-led public
URL, with owner/Entity names rendered on the page rather than required as authority in
the path.

## Identity and Authorization Matrix

| Scenario | Expected |
| --- | --- |
| signed-out internal request | authentication challenge |
| owner opens own Entity public ID | success |
| owner changes Entity name | existing identifier still resolves |
| owner requests another user's Entity ID | not found |
| valid active external token | success |
| unknown token | generic not found |
| malformed token | generic not found without broad lookup |
| revoked token | same generic not found |
| expired token | same generic not found |
| old owner/Entity slug-only public URL | no data disclosure |
| explicit `/lalas` public alias with one configured or unambiguous active Entity | success |
| explicit `/lalas` alias with missing/ambiguous Entity | generic not found |
| valid token plus foreign Entity/context parameter | grant scope remains authoritative |
| direct month endpoint with no token | generic not found |
| share revoked after page load | subsequent frame/filter request unavailable |
| two Entities with same parameterized name | stable identities remain unambiguous |

## Query Matrix

| Scenario | Expected |
| --- | --- |
| cash `EXCHANGE RETURN` for selected Entity/Context | included once |
| cash `BORROW RETURN` for selected Entity/Context | included once |
| card `EXCHANGE` for selected Entity/Context | included once |
| same Category but another Entity | excluded |
| same Entity but another Context | excluded |
| same name under another user | excluded |
| multiple Categories/Entities on one transaction | installment amount/count not multiplied |
| foreign user-card/account filter ID | rejected or empty without existence disclosure |
| selected paid state | only matching cash installments |
| normalized search | matches allowed searchable fields only |
| month with no rows | stable empty state and zero totals |
| invalid/reversed sort state | canonical default, never raw SQL interpolation |

## External Redaction Matrix

The final expected column depends on O1; every row must be explicit before development.

| Field/surface | Recommended external result |
| --- | --- |
| owner display name | visible |
| Entity display name/avatar | visible |
| description | visible |
| installment date/billing month | visible |
| installment number/count | visible |
| amount | visible |
| paid/pending | visible |
| canonical exchange-category row colours | visible without Category names |
| transaction comment | hidden |
| bank-account name/ID | hidden |
| user-card name/ID | hidden |
| unrelated Category/Entity allocations | hidden |
| reference/generated identity | hidden |
| balances, limits, audit history | hidden |
| edit/pay/destroy/correct/revert actions | absent |
| application tabs/settings/conversations | absent |
| raw internal record IDs | absent |

## Navigation Matrix

| Scenario | Expected |
| --- | --- |
| change search/filter | canonical scoped HTML URL replaces current history entry |
| select/deselect month | URL and lazy frames retain ledger identity/state |
| refresh filtered ledger | same controls and rows |
| Back/Forward | restores previous ledger state |
| cash to card tab | same authorization/identity, clean Card state, full-page navigation |
| direct lazy month refresh | authorization repeated and correct fragment returned |
| obsolete `.turbo_stream` entry | canonical HTML redirect retaining authorized scope |
| internal row navigation | stays inside internal ledger or has no action |
| external row navigation | never enters authenticated finance route |

## HTTP and Abuse Matrix

| Scenario | Expected |
| --- | --- |
| top-level public response | no-store, noindex, strict referrer headers |
| Turbo month fragment | same privacy headers |
| invalid-token burst | throttled generic response |
| valid-token ordinary use | bounded throttle does not break month loading |
| public response inspected | no session-only navigation or CSRF mutation form |
| crawler request | noindex headers and no discoverable index links |
| access telemetry failure | authorized read remains safe; no scope broadening |

## Regression Matrix

- main cash/card indexes retain their existing filters, totals, and mutations;
- KAKASHI-15 navigation specs remain green;
- category/entity allocation edits and merges remain unchanged;
- shared exchanges and returns remain synchronized exactly as before;
- actionable-message behavior is unchanged;
- financial audit and rollback records are unchanged by ledger reads; and
- the full CI suite remains the final mutation-regression gate.
