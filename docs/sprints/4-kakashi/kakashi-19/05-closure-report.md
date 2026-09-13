# KAKASHI-19 Closure Report

Status: implementation and automated verification complete as of 2026-09-12.

## Delivered Contract

- Internal ledgers use authenticated, owner-scoped Entity public IDs and the active
  Context.
- External ledgers require a revocable, expirable `LedgerShare` bearer capability.
- Cash and card membership, totals, filtering, sorting, pagination, and month loading
  use the shared `Ledgers` query and presentation vocabulary.
- External rows expose only owner/Entity identity, Context, description, date or
  billing month, installment position, amount, paid state, and the canonical
  exchange-category colour without its Category name.
- Comments, account/card names, Categories, other Entities, references, internal IDs,
  private chrome, and mutation controls remain private.
- Share lifecycle actions are owner-only and auditable. Public access telemetry is
  bounded to one write per share every five minutes and creates no financial audit.
- External responses are no-store, noindex/nofollow/noarchive, no-referrer, throttled,
  and redact bearer tokens from Rails request and redirect logs.
- Canonical URLs retain authorization and bounded mode-local query state through
  filters, lazy frames, pagination, refresh, and browser history. Cash/Card changes
  deliberately reset query state and use full-page navigation.
- The selected-month aggregate is rendered as an upward-facing bookmark attached to
  the filter section before lazy month frames finish loading, and the external shell
  uses the application's full content width. On compact screens the theme control is
  leading-aligned and the sort controls divide the available width without overflow.
- Public ledger documents carry the application favicon and expose localized
  light/dark and PT-BR/EN controls. Theme state remains browser-local, locale uses the
  public locale cookie, and neither control calls an authenticated preference endpoint.

## Compatibility Inventory

- `/internal/:entity_public_id/...` is canonical. An authenticated, unambiguous old
  Entity slug may redirect to the stable public-ID URL; the lookup is restricted to
  the current user's Entities and ambiguous or foreign matches return not-found.
- `/shared/:share_token/...` is canonical and the bearer token is the sole public
  authority.
- Old owner/Entity external slugs return not-found unless the same request already
  carries an independently valid share token, in which case they redirect to the
  canonical shared URL.
- The obsolete `Views::Lalas` and parallel cash/card templates remain removed. The
  owner-approved public `/lalas` compatibility alias delegates to the hardened ledger
  stack and fails closed unless its active Entity identity resolves unambiguously. The
  `ledger_external.html.erb` file remains intentionally as Rails' wrapper around the
  Phlex external layout.

## Automated Evidence

- Model and service coverage verifies share constraints, authorization, normalized
  searching, duplicate-free membership, bounded query count, presentation isolation,
  throttling, telemetry cadence, and failure tolerance.
- Request coverage verifies every internal/external endpoint, context and Entity
  isolation, revocation, generic errors, privacy headers, token redaction, allowlisted
  fields, mobile parity, semantic markup, and absence of public mutations.
- Browser coverage verifies canonical filtering, month selection, clean cash/card mode
  changes (including an empty selection), refresh, Back, Forward, and lazy-frame route
  retention without Turbo frame races.
- Ledger implementation does not mutate exchange, installment, balance, allocation,
  actionable-message, reference-merge, or rollback state. A separate due-date
  reference-reallocation correction discovered by full CI is documented below.

## Manual Verification Checklist

Use an Entity with both cash returns and card exchanges in the active Context.

1. Open the Entity dashboard, create a share, copy its URL, and open it in a private
   browser session.
2. Confirm the external page has no application tabs, edit links, comments,
   Categories, other Entities, account/card labels, or mutation buttons.
3. Search, change sorting, select several months, deselect the last month, paginate,
   refresh, and use Back/Forward. Switch Cash/Card and confirm mode-local parameters
   reset, the URL and visible state agree, and no `Content Missing` error appears.
4. Compare external cash/card rows and totals with the authenticated internal ledger
   for the same Entity and Context.
5. Confirm the application favicon is present. Toggle light/dark mode and PT-BR/EN,
   refresh, and verify both choices persist without an authenticated preference call.
   Narrow the viewport and confirm these controls remain aligned and the same row fields
   and amounts remain visible in a usable order in both modes and locales.
6. Open a lazy month URL directly. Confirm it remains share-authorized and an invalid,
   expired, or revoked token shows only the generic unavailable page.
7. Revoke the open share and then filter or refresh the external page. Confirm access
   stops immediately without affecting any finance record.
8. Create a replacement share and confirm the old URL stays unavailable while the new
   URL works. Inspect the Entity dashboard after five minutes to confirm bounded last
   access/count telemetry.
9. Inspect response headers for a full page, month fragment, and error: expect
   `Cache-Control: private, no-store`, `X-Robots-Tag: noindex, nofollow, noarchive`, and
   `Referrer-Policy: no-referrer`.
10. Inspect application logs and confirm shared paths contain `[FILTERED]`, never the
    raw bearer token.

## Closure Gate

Final verification on 2026-09-12:

- focused KAKASHI-19 closure suite: 85 examples, 0 failures;
- full RSpec suite: 2,046 examples, 0 failures, 92.44% line coverage;
- JavaScript suite: 26 tests, 0 failures;
- RuboCop and ERB lint: clean; and
- Bundler Audit and Brakeman: no vulnerabilities or warnings.

The first full run exposed a due-date-dependent reference-reallocation regression:
moving an explicitly unpaid installment could recreate its invoice as paid when the
destination reference date was today or earlier. The separately reviewable fix carries
the installment's paid state into the recreated projection and freezes its regression
coverage at the exact due-date boundary. The final full CI run passed afterward.
