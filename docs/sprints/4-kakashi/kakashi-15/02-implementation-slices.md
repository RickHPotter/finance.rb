# KAKASHI-15 Turbo Navigation: Implementation Slices

## Delivery Rules

- Start KAKASHI-15 only after KAKASHI-14 is accepted.
- Keep resource behavior unchanged except where URL/history correctness requires an
  explicit destination.
- Inventory and classify an action before removing its Turbo Stream response.
- Every slice adds request coverage for Turbo and non-Turbo behavior.
- Browser/system coverage verifies the address bar and history, not only visible HTML.
- A successful top-level mutation is not complete until the redirected GET resolves as
  HTML and the final browser URL matches it.
- On hybrid transaction forms, target only workflow-finishing submitters at `_top`;
  preserve hidden reactive `Update` submissions as local streams.
- Run `bin/rubocop -A` after every edit batch and `bin/ci` at completion.

## Slice 1: Baseline and Navigation-State Primitive

Capture existing regressions and introduce the bounded state contract.

Deliver:

- machine-readable inventory/classification of top-level stream usage
- safe navigation-state/return destination value object
- shared request examples for redirect status, location, failure status, and frame
  boundaries
- initial Selenium/Capybara feature harness under `spec/features` for URL, Back, Forward,
  refresh, and final-screen assertions
- characterization and deletion plan for the obsolete `/v1`
  `currentFrameUrl`/`historyStack` JavaScript shim
- shared submitter contract for `_top` plus `replace` without changing local reactive
  submitters

Coverage:

- relative allowlisted return path
- absolute/cross-host/protocol-relative rejection
- unknown query keys stripped
- foreign context/resource identifiers rejected
- deterministic canonical fallback
- Turbo Frame request never receives a full document unexpectedly
- top-level redirect destination negotiates HTML even when the unsafe request advertises
  Turbo Stream support
- replacement history is proven in a real browser, not inferred from response markup

Suggested commit:

```text
feat: define canonical Turbo navigation state
```

## Slice 2: Cash Transaction Navigation

Correct the primary `/new` regression first.

Deliver:

- normal top-level index/new/show/edit/duplicate links
- HTML new/edit entry without stream-format routing
- successful create/update/destroy `303` redirects
- retained `422` validation behavior and notification stacking
- explicit filtered/month return state
- URL-correct chain create/duplicate/finish behavior
- correct cross-navigation to related card records
- visible Create/Save/Finish/Destroy submitters use `_top`/`replace`; the hidden reactive
  `Update` submitter remains local
- obsolete cash top-level index/new/edit/create/update/destroy stream routing is removed
  once no classified caller requires it

Coverage:

- direct deep links and refresh
- `/cash_transactions -> /cash_transactions/new -> save -> /cash_transactions`
- `/cash_transactions/:id/edit -> save -> /cash_transactions`
- final index response is HTML and the address bar never remains `/new` or `/edit`
- failed create stays `/cash_transactions/new`
- failed update stays `/cash_transactions/:id/edit`
- destroy success/failure
- cancel
- duplicate
- multi-record chain and finish-without-save
- Back/Forward after each successful path
- Turbo and non-Turbo submissions
- hidden reactive `Update` refreshes form calculations without changing URL/history

Suggested commit:

```text
fix: make cash transaction navigation URL-correct
```

## Slice 3: Card Transaction Navigation

Apply the same contract while preserving selected-card and invoice state.

Deliver:

- top-level index/search/new/show/edit/duplicate navigation
- successful CRUD redirects
- selected card, year, month, and active invoice state
- URL-correct chain behavior
- classification of pay-in-advance and inline form updates as in-place actions
- correct cross-navigation to cash/source records
- submitter-level `_top`/`replace` behavior matching cash transactions

Coverage:

- all cash slice navigation cases
- selected-card index restoration
- invoice month restoration
- pay-in-advance keeps canonical index URL
- inline `Update` refresh does not claim a different resource

Suggested commit:

```text
fix: make card transaction navigation URL-correct
```

## Slice 4: Budgets, Investments, and Subscriptions

Migrate the remaining finance workflow resources.

Deliver:

- top-level new/edit/duplicate links
- successful CRUD redirects
- preserved month/filter/sort state
- explicit classification of bulk and inline actions
- validation failures on canonical form URLs

Coverage:

- one full browser CRUD/history flow per resource
- budget duplicate and bulk return path
- investment chain flow
- subscription attachment/in-place updates
- direct refresh and non-Turbo forms

Suggested commit:

```text
fix: correct finance workflow navigation history
```

## Slice 5: Categories and Entities

Migrate allocation master-data screens without changing KAKASHI-14 colour behavior.

Deliver:

- canonical index/new/show/edit navigation
- successful save/destroy destinations
- preservation of search/status state
- explicit handling of category/entity creation paths that seed transactions

Coverage:

- ordinary and built-in records
- successful create with downstream seeded transaction
- validation failure
- guarded destroy failure
- Back/Forward and refresh

Suggested commit:

```text
fix: correct category and entity navigation
```

## Slice 6: Bank Accounts and User Cards

Migrate account/card master data and their transaction-seeding branches.

Deliver:

- canonical CRUD navigation
- explicit post-save destination for ordinary and seeded-transaction flows
- safe retained return state
- no top-level `center_container` replacement

Coverage:

- create/update/destroy
- guarded destroy
- create/update followed by new transaction
- dashboard/index return
- Turbo and non-Turbo

Suggested commit:

```text
fix: correct account and card navigation
```

## Slice 7: Dashboards, Contexts, References, and Balances

Audit top-level authenticated supporting screens.

Deliver:

- URL-correct detail dashboard links
- context switching with explicit canonical destination
- reference edit/merge navigation
- balance tab/month state
- donation/static authenticated navigation classification
- nested overlay/frame actions retained where genuinely local

Coverage:

- direct links and refresh
- context switch
- reference merge success/failure
- balance lazy frame restoration
- no full document inside overlays

Suggested commit:

```text
fix: align supporting screen URLs with Turbo visits
```

## Slice 8: Health Check and Audit History

Apply the contract to the KAKASHI-09/KAKASHI-08 operational surfaces.

Deliver:

- top-level dashboard/check/audit/rollback navigation
- consistent advance behavior between Health Check and history
- repair/run streams remain local
- canonical redirect after applicable operations
- scope/filter pagination retained

Coverage:

- Health Check -> audit operation/version -> Health Check
- Back/Forward and refresh at each route
- admin/non-admin authorization unchanged
- no cyclic screen with stale URL

Suggested commit:

```text
fix: make health and audit navigation canonical
```

## Slice 9: Conversations and Internal Screens

Correct current navigation without implementing deferred KAKASHI-13 or KAKASHI-19
architecture.

Deliver:

- conversation index/show URL agreement
- actionable-message links to canonical transaction URLs
- realtime message streams retained
- internal ledger route parameters retained through filters/month navigation
- remaining authenticated top-level screens classified and migrated

Coverage:

- conversation selection, Back, Forward, refresh
- actionable create/edit transaction entry
- realtime message update does not alter URL
- internal ledger scope remains in every generated URL

Suggested commit:

```text
fix: correct conversation and internal navigation
```

## Slice 10: Cleanup and Browser Regression Suite

Remove obsolete top-level streams and prove the global contract.

Deliver:

- unused top-level `.turbo_stream.erb` removal
- removal of obsolete `format: :turbo_stream` links
- final `center_container` target audit
- removal of the legacy `/v1` history shim and its manual `format=turbo_stream`
  injection
- representative cross-resource browser journey
- Turbo cache/restore handling for destroyed resources
- completed English and Portuguese navigation/validation copy

Final verification:

```sh
bin/rspec spec/requests
bin/rspec spec/features
yarn build
bin/ci
```

Suggested commit:

```text
spec: harden Turbo URL and history regressions
```
