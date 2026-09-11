# KAKASHI-19 Implementation Slices

## Delivery Rule

Each slice is independently reviewable, covered, RuboCop-clean, and ends with a
focused commit description. Development stops after each slice for manual review.

Security boundaries land before public UI polish. No slice may retain slug-only public
authorization for compatibility. No slice changes finance mutation or actionable
message behavior.

## Slice 1 — Stable Entity Identity

**Goal:** remove mutable-name scans from internal ledger identity.

### Deliverables

- Add immutable generated `Entity#public_id` with unique database index and backfill.
- Add indexed lookup and model invariants.
- Route authenticated internal ledgers through the current user's Entity public ID.
- Preserve a decorative slug only if it does not participate in authorization.
- Cover ownership, collisions, renames, malformed IDs, and query count.

### Acceptance

- No internal request scans users or Entities.
- Another user's Entity identifier returns not-found.
- Renaming an Entity does not invalidate its ledger identity.
- Existing finance Entity URLs and merge behavior remain unchanged.

### Suggested commit

`feat: establish stable entity ledger identity`

## Slice 2 — Revocable Ledger Shares

**Goal:** replace guessable public access with an explicit capability.

### Deliverables

- Add the LedgerShare model/table and database constraints.
- Generate a high-entropy raw token and persist only its digest.
- Bind every share to exactly one Entity and Context owned by the same user.
- Implement active, expired, revoked, and rotated lifecycle rules.
- Add a resolver that returns one generic unavailable result for every invalid state.
- Cover token uniqueness, digest lookup, ownership/context integrity, expiry, and
  revocation.

### Acceptance

- User/Entity identity alone cannot open an external ledger.
- Raw tokens cannot be recovered from the database.
- Revocation is effective on the next request.
- Cross-owner or cross-context grants cannot persist.

### Suggested commit

`feat: add revocable entity ledger shares`

## Slice 3 — Explicit Ledger Access Controllers

**Goal:** enforce internal/external scope on every endpoint.

### Deliverables

- Introduce `Ledgers` controllers/policies for internal and external modes.
- Resolve access before query state or rendering.
- Require authentication unconditionally for internal controllers.
- Require an active share unconditionally for external controllers.
- Remove `User.first`, `User.all.detect`, `find_each.detect`, and path-prefix access
  inference.
- Return indistinguishable not-found responses for invalid external states.

### Acceptance

- Root, cash/card index, search, and month endpoints independently authorize.
- Request parameters cannot replace the resolved owner, Entity, or Context.
- Old slug-only external routes disclose nothing.
- Controller specs cover direct nested endpoint attacks.

### Suggested commit

`feat: enforce entity ledger access boundaries`

## Slice 4 — Canonical Ledger Query and State

**Goal:** make cash/card membership and navigation state shared and deterministic.

### Deliverables

- Add ledger-specific query-state parsing and canonical serialization.
- Add one canonical typed installment result contract for cash/card modes.
- Select installment identity before allocation joins.
- Scope user-card/account filters through the authorized owner.
- Return month counts, totals, paid state, ordering, and bounded chunks from the same
  source rows.
- Cover duplicate allocations, context isolation, special categories, invalid state,
  and query count.

### Acceptance

- Counts, totals, rows, and month buttons reconcile.
- Cash/card category semantics remain unchanged.
- Foreign filter IDs cannot probe or broaden data.
- Internal and external modes receive identical financial membership.

### Suggested commit

`feat: unify entity ledger queries`

## Slice 5 — Safe Shared Presentation

**Goal:** converge the two access modes without exposing internal models externally.

### Deliverables

- Add shared ledger page, filter, month, empty, total, and responsive row primitives.
- Add distinct internal and external row presenters over the canonical result.
- Render explicit owner, Entity, Context/scope, and last-updated identity.
- Apply the confirmed external field allowlist and prove redactions.
- Keep external pages free of mutation controls and private application chrome.
- Preserve accessible Category colours/entity avatars only where allowed.

### Acceptance

- Shared layout does not imply shared authorization or field exposure.
- Adding a private model field cannot make it render externally.
- Cash/card desktop and mobile rows use the same result semantics.
- Empty and unavailable states are clear in light and dark mode.

### Suggested commit

`feat: present safe internal and external ledgers`

## Slice 6 — Share Management

**Goal:** let an owner control external access from the Entity workflow.

### Deliverables

- Add share creation to the Entity dashboard.
- Show active/expired/revoked state, creation, expiry, last access, and access count.
- Provide copy-on-create, revoke, and rotate actions.
- Keep raw tokens out of later persistence/rendering.
- Audit lifecycle mutations without producing financial audit versions.
- Add localized confirmation and failure feedback.

### Acceptance

- An owner can create, copy, inspect, revoke, and replace a share.
- Another user cannot manage the share.
- Revoking one share does not affect finance data or unrelated shares.
- Failed lifecycle mutations are atomic and actionable.

### Suggested commit

`feat: manage external entity ledger shares`

## Slice 7 — Canonical Routes and Turbo Navigation

**Goal:** make every ledger state refreshable without route-family drift.

### Deliverables

- Establish canonical internal and token-authorized external route families.
- Preserve authorization and query state through cash/card tabs, filters, month lazy
  loads, sorting, and pagination.
- Apply KAKASHI-15 `_top`/replace/history conventions.
- Add safe compatibility behavior for old internal bookmarks.
- Make old external slug-only routes unavailable unless an independent valid share is
  present.
- Cover refresh, Back/Forward, rapid filtering, and direct frame navigation.

### Acceptance

- The address bar always matches visible ledger state.
- Internal and external links never cross modes.
- No frame request loses Entity/Context/share scope.
- Obsolete stream URLs canonicalize safely.

### Suggested commit

`fix: make entity ledger navigation canonical`

## Slice 8 — Public HTTP Hardening

**Goal:** make public financial reads resistant to indexing, caching, and enumeration.

### Deliverables

- Add noindex, no-store, and strict referrer headers to all external responses.
- Add bounded rate limiting for valid and invalid share requests.
- Ensure logs and error pages do not expose raw token values.
- Bound access telemetry writes and update only after successful authorization.
- Add security request coverage for HTML, fragments, errors, and throttling.

### Acceptance

- Privacy headers appear on every external response path.
- Invalid-token enumeration is bounded and indistinguishable.
- Share secrets do not appear in application logs beyond unavoidable sanitized route
  handling.
- Internal ledger performance is unaffected by public throttling.

### Suggested commit

`security: harden public entity ledger access`

## Slice 9 — Namespace Migration and Closure

**Goal:** remove parallel `lalas` drift and close the feature with evidence.

### Deliverables

- Move remaining domain code and views from `Lalas` to `Ledgers`.
- Remove obsolete unscoped `/lalas` behavior and unused route/controller/view copies.
- Keep only deliberate, tested compatibility shims.
- Add request, service, feature, mobile, accessibility, query-count, and regression
  coverage.
- Produce a manual verification checklist and closure inventory.
- Run RuboCop, focused suites, and full CI.

### Acceptance

- No production path uses `User.first`, broad name scans, or slug-only authorization.
- One canonical query/presentation vocabulary serves both modes.
- External pages contain only allowlisted fields and controls.
- Full CI passes without changes to finance mutations or actionable messages.

### Suggested commit

`test: close hardened entity ledger coverage`
