# KAKASHI-19 Current Behavior and Gap Inventory

## Existing Routes

The application currently exposes three parallel route families:

```text
/lalas/...
/internal/:entity_slug/...
/:user_slug/external/:entity_slug/...
```

Each family has cash/card indexes plus `month_year` and `search` collection routes.
KAKASHI-15 already made internal/external filter submissions and lazy month URLs retain
their route parameters and canonical HTML navigation.

## Existing Resolution

`LalasController` currently:

- skips authentication globally and conditionally re-enables it for paths beginning
  with `/internal/`;
- selects `User.first` for the unscoped `/lalas` family;
- resolves external users with `User.all.detect` over a parameterized first name/email;
- resolves Entities with `find_each.detect` over a parameterized `entity_name`;
- derives external authorization from the presence of matching guessable slugs;
- always scopes data to the resolved user's main Context; and
- builds tab links separately for cash and each matching user card.

User UUID identity already exists. Entity stable public identity and external share
grants do not.

## Existing Financial Scope

Cash ledger membership uses:

- the resolved user's main Context;
- the selected Entity;
- built-in `EXCHANGE RETURN` and `BORROW RETURN` Categories; and
- optional search, paid/pending, account, and month state.

Card ledger membership uses:

- the resolved user's main Context;
- the selected Entity;
- built-in `EXCHANGE` Category;
- the selected owned UserCard where present; and
- optional search, price/installment, and month state.

The intended category/entity filtering exists, but it is assembled independently in
both controllers and still accepts broad transaction-shaped parameter lists that a
read-only ledger does not need.

## Existing Presentation

`Views::Lalas` duplicates cash/card index, filter, month container, month section, and
installment-row presentation. It resembles the main finance indexes but has drift:

- `Views::Lalas::CardTransactions::Index` assigns `User.first` rather than the resolved
  ledger owner;
- cash and card have different filter vocabularies and context plumbing;
- rows receive full transaction models and render Category and Entity allocation
  popovers;
- description, date, installment number, amount, Categories, Entities, and cash paid
  state are exposed;
- external and internal modes share most view classes without an explicit redaction
  contract;
- public pages inherit application layout/chrome behavior rather than owning a public
  ledger shell; and
- totals, owner/Entity identity, share state, last update, and clear empty/error states
  are incomplete or implicit.

No row mutation controls were found in the dedicated ledger rows, but safety currently
depends on what those reused components happen to render.

## Existing Coverage

Request coverage proves portions of the current behavior:

- main-context isolation;
- entity isolation for dynamic slug routes;
- current-user ownership for internal cash routes;
- cash/card route rendering;
- internal/external filter and lazy-frame route preservation; and
- canonical HTML entry after KAKASHI-15.

Current coverage does not establish:

- token/share authorization;
- revocation or expiration;
- stable indexed lookup;
- indistinguishable not-found behavior;
- external field redaction;
- absence of private chrome and mutation affordances;
- rate limits and privacy headers;
- share management;
- context-bound grants;
- cross-user card/account parameter attacks;
- duplicate-allocation amount safety;
- pagination/chunk boundaries; or
- query-count behavior.

## Security Gaps

| Gap | Consequence | Required boundary |
| --- | --- | --- |
| guessable owner/Entity slugs authorize external reads | names disclose financial data | opaque revocable share grant |
| `User.all.detect` and `find_each.detect` | enumeration and O(n) request work | indexed immutable identity/digest lookup |
| conditional authentication inferred from request path | fragile controller-wide access mode | explicit internal/external controllers or policies |
| `User.first` fallback | accidental first-user disclosure | remove unscoped public fallback |
| full models passed to public views | future fields can leak by reuse | explicit external row presenter/DTO |
| broad transaction parameter permits | attacker-controlled irrelevant filters | ledger-specific query-state allowlist |
| owner card/account IDs accepted from params | possible cross-owner probing | validate within authorized owner/query scope |
| no revocation/expiry | shared URL remains valid forever | lifecycle state checked on every endpoint |
| no privacy headers/throttle | indexing, caching, brute-force pressure | external response policy and rate limiting |

## Navigation and Maintenance Gaps

| Gap | Consequence | Required boundary |
| --- | --- | --- |
| three route families | behavior and tests drift | canonical internal and external families |
| `lalas` naming | domain intent is unclear | `Ledgers` namespace |
| duplicated cash/card context hashes | fixes land on only one surface | shared ledger query state and route state |
| duplicated rows from main finance indexes | styling and semantics drift | shared primitives with explicit ledger presenters |
| scope carried mainly through link helpers | direct nested requests may bypass assumptions | authorize and scope every controller action |
| no owner/share header | viewer cannot verify whose ledger is shown | explicit owner, Entity, scope, and freshness summary |

## Migration Risks

- Existing bookmarks may point at internal/external slug routes.
- External slug URLs must stop authorizing immediately when the secure contract ships;
  compatibility cannot preserve an insecure public capability.
- Entity names may collide after parameterization even though the stored names differ.
- Changing Entity names must not invalidate an internal bookmark or active share.
- Turbo lazy frames can appear authorized at page load but fail later if revocation is
  not checked again.
- Token access telemetry can create write contention if updated for every fragment;
  it must be throttled/coalesced or limited to top-level access.
- Reusing main finance rows can reintroduce mutation links or private identifiers.
- Renaming constants/routes in one step can make rollback difficult; compatibility
  shims must be narrow and temporary.

## Existing Assets Worth Reusing

- `User#public_id` generation and unique indexing patterns;
- KAKASHI-15 canonical top-level Turbo navigation rules;
- normalized text search;
- shared MonthYear selector and responsive layout primitives;
- category colour presentation and entity avatar components;
- canonical finance finder behavior where it can accept pre-authorized scopes; and
- the application's audit and health-check registries for operational visibility.

## Immediate Conclusion

The current pages are a useful visual prototype and partial query proof, not a safe
public-sharing implementation. KAKASHI-19 should establish authorization and safe row
identity before attempting style parity or namespace cleanup.
