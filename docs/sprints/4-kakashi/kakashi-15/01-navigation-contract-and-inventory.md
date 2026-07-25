# KAKASHI-15 Turbo Navigation: Contract and Inventory

## Objective

Make browser URL, browser history, rendered screen, and server resource agree after
every top-level navigation and form submission while retaining Turbo Streams for
genuinely local updates.

## Locked Product Decisions

- Index, new, show, edit, and duplicate are top-level resources/screens.
- Top-level links use normal Turbo Drive visits and target `_top` when nested in a
  frame.
- Top-level paths do not add `format: :turbo_stream`.
- `center_container` may remain a stable layout boundary, but is not a router.
- Successful create, update, and destroy actions redirect to a canonical GET with
  `303 See Other`.
- A successful submission replaces its form/history entry, preventing Back from
  reopening a stale successfully submitted form.
- Validation failure returns `422 Unprocessable Content`, retains entered values, and
  leaves the canonical new/edit URL visible.
- Turbo Streams remain appropriate for validation fragments, notifications, modals,
  lazy month/detail fragments, inline payment/state controls, bulk selection results,
  and realtime updates.
- Filter/month/context return state is explicit and allowlisted.
- Chained create/duplicate remains supported and refreshable.
- Turbo and non-Turbo requests share the same canonical destinations.

## Screen and URL Contract

| Screen | Canonical URL behavior |
| --- | --- |
| index | resource collection URL plus explicit query state |
| new | resource `/new` URL plus permitted seed/chain/return state |
| show | member URL |
| edit | member `/edit` URL plus permitted return state |
| duplicate | existing member duplicate URL, which identifies the source |
| successful create | redirect to explicit index/chain destination |
| successful update | redirect to explicit return/index/show destination |
| successful destroy | redirect to validated return/index destination |
| failed create | stay on the original `/new` browser URL |
| failed update | stay on the original `/edit` browser URL |
| cancel | normal GET to validated return destination or resource default |

A response must not render an index while `/new` or `/edit` remains in the address bar.
A frame response must not insert a complete application document inside a nested frame.

## History Contract

### Advance

Use normal `advance` behavior for user-directed GET navigation:

- index to new/show
- show to edit/duplicate/related resource
- tabs and menus between top-level screens
- explicit pagination/filter submissions that should be revisitable
- Health Check and audit-history navigation

Default Turbo Drive history behavior is sufficient where no explicit attribute is
needed.

### Replace

Use `replace` for:

- the redirect destination after a successful create/update/destroy
- continuation from one successfully saved chained form to the next form
- canonicalization redirects that only correct the current location
- filter controls explicitly documented as replacing transient state rather than
  creating a history entry

After `index -> new -> successful create -> index`, Back returns to the index state
that preceded `new`; it does not reopen the submitted form.

### Restore

Back/Forward restoration must:

- display the URL's resource and query state
- restore cached pages only when their server resource still exists
- allow Turbo to refetch when cache invalidation is safer
- avoid re-submitting non-GET requests
- reconnect lazy frames without duplicating content/controllers

Destroying a record must prevent Back from presenting an actionable stale show/edit
screen. Marking destructive source screens as non-previewable or forcing a refetch is
acceptable.

## Navigation State Contract

Use one small explicit navigation-state object/helper rather than accepting arbitrary
paths or copying all request parameters.

Permitted state families:

- `return_to`: relative, same-application, allowlisted route and query keys
- selected context/scenario identifier when already part of the application's context
  contract
- index search/filter/sort state
- month/year and active month selections
- selected user card or bank account
- chain mode, continuation flag, and owned created-record identifiers
- duplicate source represented by the duplicate route
- safe seed attributes already supported by a destination form

Rules:

- reject absolute, protocol-relative, cross-host, malformed, and non-allowlisted paths
- reject foreign-user/context record identifiers
- retain only known scalar/array keys with bounded size
- never put prices, comments, notification payloads, or other sensitive form data in
  navigation state
- use route helpers to generate the destination after validation
- fall back to the resource's canonical index when state is invalid or absent

The contract may be a focused value object plus controller methods. It must keep route
decisions visible at each action rather than hiding them in a global responder.

## Submission Contract

### Success

1. Persist the mutation.
2. complete required synchronization/audit work
3. choose a named canonical GET destination
4. redirect with `303 See Other` and the success flash
5. allow Turbo to visit the redirect at the top level using replacement history

### Validation failure

1. do not redirect
2. render the same new/edit screen or its bounded validation streams
3. return `422 Unprocessable Content`
4. retain submitted values and stacked notifications
5. do not change the visible URL

### Non-Turbo requests

Successful non-Turbo submissions follow the same `303` destination. Failed non-Turbo
submissions render the same form with `422`. Progressive behavior must not depend on a
Turbo Stream template.

## Chained Create and Duplicate

Cash/card chained entry keeps these modes:

- create one and finish
- create and continue with a fresh record
- duplicate one and finish
- duplicate and continue from the latest created record
- finish a chain without saving the currently blank form

Each continuation performs a top-level replace visit to a canonical new/duplicate URL
whose permitted navigation state is sufficient to refresh the page. Created record IDs
must be owned by the current user/context before use. Finishing redirects to the
canonical index with the intended card/month/filter state.

Back from the finished index returns to the screen before the chain began, not to every
successfully submitted intermediate form.

## Turbo Stream Boundary

Keep streams for:

- form validation notification stacking
- nested form recalculation/refresh
- modals, overlays, sheets, and confirmation flows
- lazy month-year containers and dashboard fragments
- bulk actions that intentionally keep the same index URL/state
- inline pay/paid-state controls
- realtime conversation messages
- Health Check run/repair status

Do not use streams merely to:

- open a top-level new/edit/index/show screen
- render an index after successful CRUD
- switch a top-level tab while preserving the old URL
- make a successful save appear faster while leaving the form URL behind

## Current Repository Inventory

### Top-level `center_container` screens

The current application wraps most finance screens in `center_container`, including:

- cash/card transactions and budgets
- categories, entities, bank accounts, user cards, investments, and subscriptions
- balances, references, contexts, conversations, and donation
- Health Check and audit history/rollback
- internal ledger (`lalas`) screens

The wrapper itself is not necessarily wrong. The migration target is every link or
response that treats it as a navigation destination.

### Current top-level stream replacements

The initial audit found create/update/destroy/index/new/edit stream templates replacing
`center_container` for:

- cash transactions
- card transactions
- budgets
- categories
- entities
- investments
- subscriptions
- user bank accounts
- user cards

Conversation show and donation also require classification. Some may remain streams
only for a nested/realtime path; their top-level entry must still be URL-correct.

### Current stream-format top-level links

The initial audit found explicit `format: :turbo_stream` top-level links in:

- cash/card/budget/investment index navigation
- mobile floating create actions
- transaction cross-navigation
- message/actionable-transaction entry

Every occurrence must be classified as top-level navigation or in-place interaction.

### Controllers with broad stream responders

The initial audit includes:

- cash/card transactions and installments
- budgets
- categories and entities
- investments and subscriptions
- bank accounts and user cards
- conversations and messages
- internal ledger controllers

Each action receives an explicit disposition: canonical redirect, top-level HTML
render, validation stream, nested fragment, modal, bulk in-place mutation, or realtime
update.

## Resource Migration Order

1. cash transactions
2. card transactions
3. budgets
4. investments and subscriptions
5. categories and entities
6. user bank accounts and user cards
7. balances, references, contexts, and dashboards
8. Health Check and audit history
9. conversations/messages in their current pre-KAKASHI-13 shape
10. internal authenticated ledgers and remaining static/authenticated screens

KAKASHI-13 later reuses this contract for rebuilt conversation routes. It does not
justify leaving current conversation navigation knowingly inconsistent.

## Explicitly Out of Scope

- redesigning forms or finance domain behavior
- replacing Turbo/Hotwire with another navigation framework
- implementing KAKASHI-13 friendship/conversation architecture
- implementing KAKASHI-19 ledger authorization redesign
- preserving arbitrary third-party or cross-origin `return_to` URLs
- turning every in-place stream into a full-page redirect
