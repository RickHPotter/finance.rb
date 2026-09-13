# KAKASHI-19 Ledger Product and Security Contract

## Purpose

KAKASHI-19 turns the existing entity-specific cash and card pages into an explicit
ledger product with two access modes:

- an authenticated internal ledger owned by the signed-in user; and
- a deliberately shared, revocable, read-only external ledger.

The feature must preserve the finance meaning already used by the current ledger:
card `EXCHANGE` installments and cash `EXCHANGE RETURN` / `BORROW RETURN`
installments for one Entity. It must not alter exchange creation, synchronization,
actionable messages, paid-history rules, projections, audits, or rollback.

## Product Boundary

A ledger answers: “What exchange-related installments involving this Entity are in
this Context, and what is their current paid state?” It is not a generic public copy
of the owner's finance indexes.

The internal ledger may use authenticated owner-only presentation. The external
ledger is a separately authorized projection with an explicit field allowlist. Shared
views never infer safety from the fact that the underlying record is visible
internally.

## Canonical Identity

### Users

`User#public_id` already exists and is uniquely indexed. It may identify an owner in
internal application contracts, but a user identifier never authorizes a public
ledger request.

### Entities

Entities need an immutable, generated, uniquely indexed `public_id`. Display names and
parameterized slugs remain presentation only because they are mutable, non-unique
across users, guessable, and expensive to resolve by scanning.

Internal lookup is always equivalent to:

```text
current_user.entities.find_by!(public_id: route_identifier)
```

No internal route may resolve another user's Entity and then attempt to hide the data
later in the query or view.

### External shares

Public access requires a dedicated share grant. The recommended shape is a
`LedgerShare` owned through an Entity and bound to one Context, with:

- an opaque, high-entropy bearer token;
- only a one-way token digest persisted;
- `expires_at` when the owner chooses an expiry;
- `revoked_at` for immediate revocation;
- `last_accessed_at` and an access count for owner visibility; and
- timestamps and stable audit identity.

Knowing a user public ID, Entity public ID, old user slug, Entity name, or route shape
is insufficient. Token lookup must avoid broad scans and compare canonical digests.
The raw token is shown only when created or rotated.

## Authorization

### Internal

- Authentication is mandatory before any resource lookup.
- The Entity must belong to `current_user`.
- The ledger Context must belong to `current_user`.
- Context choice is resolved server-side, never trusted from an arbitrary context ID.
- Invalid, inactive where prohibited, cross-user, or cross-context identifiers return
  the same not-found response.

### External

- Authentication is not required; a valid active bearer share is required.
- The share resolves the owner, Entity, and Context. Request parameters cannot replace
  any of those identities.
- Revoked and expired shares behave exactly like unknown shares.
- All nested cash, card, month, search, and filter endpoints repeat authorization;
  authorization at the initial HTML page is not inherited by later Turbo requests.
- The response does not reveal whether an owner, Entity, Context, or expired share
  exists.

## External Field Boundary

The default external projection is intentionally minimal. Pending owner confirmation,
the recommended allowlist is:

- owner display name and Entity display name/avatar;
- installment description;
- installment date or card billing period;
- installment number/count;
- installment amount;
- paid/pending state; and
- aggregate count and amount for the currently filtered result.

The recommended default redactions are:

- transaction comments;
- bank-account and user-card names or identifiers;
- unrelated Categories and Entities;
- account/card balances and limits;
- references and generated-record identities;
- audit history and rollback state;
- internal transaction/installment IDs in HTML or URLs;
- mutation links, buttons, forms, and Turbo actions; and
- private application navigation, settings, conversations, notifications, and user
  email.

External rows are built from a safe presenter/DTO. They are not full Active Record
objects handed to a shared internal view.

## Query Contract

One server-side ledger query owns both cash and card retrieval. Inputs are explicit:

- authorized Entity;
- authorized Context;
- kind (`cash` or `card`);
- selected month-years;
- normalized search term;
- paid state where supported;
- deterministic sort and direction; and
- bounded pagination or chunk identity.

The query fixes identity before joining allocations so an installment cannot be
duplicated by multiple Categories or Entities. Cash membership requires the canonical
cash exchange-return categories; card membership requires `EXCHANGE`; both require
the selected Entity and Context. User-card filtering is owner-derived and cannot
select another user's card.

Internal and external modes consume the same result rows. Authorization and
presentation differ; financial membership does not.

## Navigation Contract

- Filters and month selection produce canonical HTML URLs with Turbo action `replace`.
- Lazy month frames preserve ledger mode, ledger identity, share authorization, and
  all relevant filter state.
- Cash/Card mode changes retain only ledger identity and authorization. They use a
  full-page navigation and reset mode-local months, search, sort, paid state, and
  pagination so incompatible frame state cannot cross modes.
- Refresh, Back, and Forward restore the same ledger state.
- Internal links never escape to external routes.
- External links never escape to authenticated finance indexes.
- External pages contain no link that requires the owner session to make sense.
- Obsolete `.turbo_stream` entry URLs canonicalize without dropping scope.

Bearer secrets should not be copied into unrelated query values, analytics, or client
logs. The canonical public route shape is an open decision, but it must keep the share
secret inside the ledger route contract and apply a strict referrer policy.

## Public HTTP Safety

Every external response, including Turbo month fragments and errors, must set:

- `X-Robots-Tag: noindex, nofollow, noarchive`;
- `Cache-Control: private, no-store`;
- a strict `Referrer-Policy` that does not send the share URL elsewhere; and
- content-type and framing protections already required by the application.

Public ledger endpoints receive an application-level throttle keyed by a combination
of network identity and share lookup identity. A missing/invalid token is rate-limited
without first resolving names. Throttling never replaces authorization.

## Share Lifecycle

The owner can:

1. create a share from the Entity dashboard;
2. copy its URL at creation time;
3. view creation, expiry, revocation, last-access, and access-count state;
4. revoke it immediately;
5. rotate it by revoking the old grant and creating a new token; and
6. create a new share after a previous share expires or is revoked.

Creation and revocation are auditable owner actions. Public reads must not generate
financial audit versions or touch finance records; access telemetry is updated through
a bounded write path that cannot make authorization depend on telemetry success.

## Naming and Migration

`lalas` is an ambiguous legacy namespace. New domain code uses `Ledgers` and
`Views::Ledgers`. Migration may temporarily retain named legacy route helpers, but no
new business logic is added under `Lalas`.

Compatibility routes must either redirect safely to a route the requester is already
authorized to use or return not-found. An old guessable external slug can never be
upgraded into public access automatically.

## Frozen Boundaries

KAKASHI-19 does not change:

- exchange/return categories or signs;
- installment amounts, dates, paid state, or balances;
- shared transaction creation or synchronization;
- actionable-message sending, receiving, auto-apply, correction, supersession, read
  state, or revert;
- Category/Entity allocation mutation rules;
- reference projections or merges; or
- audit rollback eligibility.

## Open Owner Decisions

1. Exact external field allowlist, especially descriptions, paid state, source
   account/card labels, Categories, and comments.
2. Share granularity and expiry defaults: one Entity/Context grant for cash plus card
   is recommended, with optional expiry and no automatic expiry by default.
3. Context and URL policy: whether internal ledgers follow the active Context or stay
   main-context-only, and whether canonical public URLs use only the opaque token or
   retain decorative owner/entity slugs beside it.
