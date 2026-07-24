# KAKASHI-09 Health Check: Product and Execution Contract

## Objective

Replace the current Settings audit-tab collection with an administrator-only Health
Check workspace. The workspace must answer five questions without requiring an
administrator to open every audit:

1. Which checks are healthy, warning, failing, running, or unavailable?
2. Which user, context, and connected-user scope was checked?
3. Which records are affected and why?
4. Which findings can be repaired, and why are the other actions unavailable?
5. Which audited application operation applied a supported repair?

This feature reorganizes and hardens the current audit and correction services. It does
not replace their financial rules with a second implementation.

## Locked Product Decisions

- `GET /healthcheck` is the canonical application-health workspace.
- `GET /settings` temporarily redirects to `/healthcheck`; it is not a second
  rendering path.
- Rails' process-level `GET /up` endpoint remains unchanged and separate.
- The Health Check workspace, its check endpoints, Naming Convention maintenance, and
  every repair endpoint are administrator-only.
- Non-admin users retain their KAKASHI-08 audit-history permissions. Health Check
  authorization must not narrow record-history access.
- The workspace is scoped to the signed-in administrator and the administrator's
  selected `current_context`, not to every user in the database.
- Exchange checks may inspect all user relationships intentionally connected to the
  current administrator or may be narrowed to one validated connected user.
- Checks run asynchronously through Solid Queue.
- Persist only the latest execution metadata and normalized counts for a check scope.
  Do not persist copies of financial finding payloads.
- Details are evaluated from current data, lazy-loaded, and paginated.
- The initial registry includes Piggy Bank integrity even though the original
  KAKASHI-09 outline did not name it explicitly.
- V1 exposes only existing repair capabilities after extracting and hardening them.
- There is no global `Repair all` action. `Run all` is diagnostic only.
- Naming Convention remains a maintenance tool, visually separate from health
  failures.
- Backup download stays in its current application location. Health Check does not
  duplicate it in V1.
- A generic balance-recalculation control is not exposed until it has its own bounded
  preview, authorization, and safety contract.

## Current Surface and Migration Boundary

The current implementation consists of:

- `SettingsController`, which renders the maintenance page
- a large `Admin::SettingsController`, which loads several audits and applies repairs
- `Views::Settings::Show`
- large `Views::Admin::Settings::*` audit views
- `naming-tabs`, which also serves non-settings surfaces such as balances
- immediate mutation paths for some repairs
- a card-projection repair embedded in `CashTransactionsController`

KAKASHI-09 replaces these boundaries with a Health Check dashboard, registry-backed
check adapters, focused run/detail/repair controllers, and focused repair services.

The underlying audit algorithms remain authoritative until a focused regression test
proves that a service change is required for scope, pagination, or normalization.

## Access and Routing Contract

### Canonical routes

The route family should expose these responsibilities without restoring a monolithic
controller:

| Responsibility | Method and path |
| --- | --- |
| dashboard | `GET /healthcheck` |
| run all checks | `POST /healthcheck/runs` |
| rerun one check | `POST /healthcheck/checks/:check_key/run` |
| lazy check details | `GET /healthcheck/checks/:check_key` |
| repair preview | `POST /healthcheck/checks/:check_key/repairs/:repair_key/preview` |
| repair apply | `PATCH /healthcheck/checks/:check_key/repairs/:repair_key` |
| naming preview | `GET /healthcheck/maintenance/naming-convention` |
| naming apply | `PATCH /healthcheck/maintenance/naming-convention` |
| legacy redirect | `GET /settings` |

Exact helper names may follow Rails routing conventions, but generated paths and DOM
identifiers must use the `healthcheck` or `health_check` vocabulary rather than
`settings_*`.

### Authorization behavior

- Unauthenticated requests follow the existing Devise authentication flow.
- Authenticated non-admin requests to Health Check endpoints return `404`, matching the
  existing non-discoverable admin behavior.
- The legacy `/settings` endpoint redirects to `/healthcheck`. Authorization is
  enforced at the canonical destination.
- Health Check navigation is rendered only for administrators.
- A check key or repair key that is not in the registry returns `404`.
- A connected-user ID that is not valid for the current administrator returns `404`;
  it never broadens the check silently.

The redirect is temporary compatibility behavior. Its eventual removal is outside V1
and requires a separate decision after saved links have had time to migrate.

## Scope Contract

Every run, detail query, preview, and apply action receives one explicit
`HealthCheck::Scope` containing:

- current administrator ID
- selected context ID and scenario key
- optional connected-user ID
- locale

The scope object validates live records instead of trusting submitted IDs.

### Context-only checks

These checks read only records belonging to `current_context`:

- Exchange Return
- Card-bound Exchange Projection
- Piggy Bank

### Connected-relationship checks

These checks read the selected context and the current administrator's intentional
user connections:

- Exchange Trio and canonical reference chain
- Misplaced loan/reimbursement intent

With no connected-user filter, the checks cover all relationships visible to the
current administrator. With a filter, they cover only that validated user pair.
Neither mode becomes a global all-user audit.

The Exchange Trio audit must accept `current_context` explicitly. Conversation and
message selection must use the selected context's scenario key, and counterpart
resolution must use the matching connected-user context. A selected connected user
cannot cause rows from another scenario or unrelated context to enter the result.

### Scope display

The dashboard and detail header show:

- administrator identity
- selected context name and scenario badge
- `All connected users` or the selected connected user's identity, when applicable
- last-run timestamp
- duration

Context switching continues through the application's existing context switcher. A
switch changes the Health Check scope and therefore selects a different set of latest
execution rows.

## Workspace Structure

### Overview

The first screen renders only registry metadata and persisted latest-run summaries. It
does not render audit finding rows.

It contains:

- total counts for healthy, warning, failing, running, and unavailable checks
- scope summary
- one summary card per registered check
- `Run all`
- per-check `Run` or `Rerun`
- last-run time and duration
- affected, warning, failure, repairable, and read-only counts
- availability explanations

A check that has never run is displayed as unavailable with a localized `Never run`
reason. `GET /healthcheck` remains read-only; the first visit does not enqueue work.

### Financial integrity

Each registered financial check receives a summary card and lazy details endpoint.
Opening one card loads only that check's current detail page.

### Maintenance tools

Naming Convention remains available under a separate Maintenance heading. Naming
suggestions never increment Health Check warning or failure totals.

Audit history remains linked for administrators so a repair result can be followed to
its KAKASHI-08 operation. The general audit-history routes remain outside the
administrator-only Health Check namespace because KAKASHI-08 grants ordinary users
owner-scoped history access.

## Initial Registry

The registry is the only top-level discovery mechanism. Adding a check must not add a
new dashboard controller branch.

| Stable key | Title | Scope | Default severity | V1 capability |
| --- | --- | --- | --- | --- |
| `exchange_trio` | Exchange Trio and Reference Chain | context and optional connected user | error | diagnostic; selected reference repairs |
| `exchange_return` | Exchange Return Integrity | context | error | diagnostic; selected allocation corrections |
| `card_exchange_projection` | Card-bound Exchange Projections | context | error | diagnostic; selected projection repairs |
| `misplaced_exchange_intent` | Misplaced Loan/Reimbursement Intent | context and optional connected user | error | diagnostic; selected intent conversions |
| `piggy_bank` | Piggy Bank Integrity | context | error | diagnostic only |

Reference/invoice and balance-projection checks are not registered as empty roadmap
cards. They become visible when an actual runner and result contract exist.
`unavailable` represents a real current execution or scope condition, not an
advertisement for unimplemented work.

### Registry entry contract

Every entry declares:

- stable key
- group
- translated title and description keys
- default severity
- scope kind
- runner class
- detail provider class
- supported repair definitions
- availability resolver

Translated display text does not become an identifier. Routes, persistence, jobs,
tests, and DOM IDs use the stable key.

## Normalized Result Contract

Audit services may retain private domain hashes internally. A check adapter converts
them into a common `HealthCheck::Result`:

```ruby
HealthCheck::Result.new(
  check_key: "exchange_return",
  outcome: "failing",
  severity: "error",
  scope: {
    user_id: 12,
    context_id: 34,
    connected_user_id: nil
  },
  counts: {
    affected: 8,
    failures: 8,
    warnings: 0,
    repairable: 2,
    read_only: 6,
    unavailable_actions: 4
  },
  started_at:,
  finished_at:,
  duration_ms:,
  error_code: nil
)
```

The result object:

- accepts only registered keys
- validates outcome and severity vocabularies
- normalizes missing counts to zero
- uses integer counts and milliseconds
- carries identifiers, not Active Record objects
- does not carry raw finding payloads
- is immutable after construction

### Execution state

Persisted execution state uses:

- `queued`
- `running`
- `completed`
- `unavailable`

Completed outcome uses:

- `healthy`
- `warning`
- `failing`

The dashboard derives one display state:

1. queued or running execution -> `running`
2. unavailable execution -> `unavailable`
3. completed execution -> completed outcome
4. no execution -> `unavailable` with `never_run`

### Outcome rules

- `healthy`: no failure or warning findings
- `warning`: at least one warning and no failure findings
- `failing`: at least one failure finding
- `unavailable`: the check could not produce a trustworthy result

A mixed repair result never changes a check directly to healthy. Only the mandatory
post-apply rerun can produce a new healthy outcome.

### Severity

Severity describes the impact of a finding, while outcome summarizes the check:

- `error`: financial structure or behavior is inconsistent
- `warning`: a suspicious or degraded state requires review but is not proven corrupt
- `information`: explanatory detail that does not affect outcome

An adapter may override the registry's default severity for individual findings. For
example, Card Projection can report both projection errors and shape warnings.

## Latest Execution Persistence

Add a small operational model for the latest result in each scope. It is not financial
history and is not PaperTrail-audited.

The persisted row contains:

- check key
- administrator/user ID
- context ID
- nullable connected-user ID
- execution generation token
- execution state
- nullable completed outcome
- normalized counts as bounded JSONB
- queued, started, and finished timestamps
- duration in milliseconds
- sanitized error code
- created and updated timestamps

Use partial unique indexes so there is one row for:

- each check/user/context with no connected-user filter
- each check/user/context/connected-user selection

Rerunning updates that latest row in place. V1 does not retain historical diagnostic
runs. KAKASHI-08 remains the durable history for actual financial mutations.

The row must not store:

- record descriptions
- prices
- raw audit rows
- before/after repair values
- exception backtraces
- credentials or request parameters

## Asynchronous Execution

### Run one

1. Validate administrator, check key, context, and connected-user scope.
2. Generate a new execution generation token.
3. update the latest row to `queued` and clear its previous outcome/error.
4. enqueue one Health Check job with identifiers and the generation token.
5. return a Turbo response that renders the check as running.

### Run all

1. Resolve the registry for the current scope.
2. enqueue one independent job per available registered check.
3. do not load detail rows in the request.
4. do not apply any repair.
5. preserve an already queued/running execution rather than enqueueing duplicates.

One check failure does not cancel the other checks.

### Job behavior

Each job:

1. reloads and revalidates the administrator, context, connected user, registry entry,
   and generation token
2. transitions the latest row to `running`
3. executes the adapter with the explicit scope
4. validates a normalized result
5. writes counts, outcome, timestamps, and duration
6. broadcasts the updated summary card and overview counters through Turbo

The generation token prevents an older job from overwriting a newer rerun. A job that
loses authorization or scope marks the matching generation unavailable with a
sanitized reason.

Exceptions are logged with normal server diagnostics, while the persisted row and UI
receive a bounded error code. Raw exception messages must not expose record values or
internal SQL.

## Lazy Detail and Pagination Contract

The dashboard never embeds full finding collections.

`GET /healthcheck/checks/:check_key`:

- revalidates the same scope
- evaluates current detail data through the registered provider
- returns a bounded page
- defaults to 25 rows
- caps `per_page` at 100
- orders deterministically with a stable record-ID tiebreaker
- renders the check description, scope, latest summary, live-detail timestamp,
  findings, actions, and pagination

Because finding snapshots are deliberately not persisted, live details can differ
from the last-run counts if data changed afterward. The UI labels both timestamps and
offers `Rerun`; it never claims that live rows are a historical snapshot.

Adapters should push filtering and pagination into database queries where practical.
Where a legacy audit must inspect a complete bounded graph to determine correctness,
the provider may paginate normalized results after evaluation, but the contract must
allow later query optimization without changing the view.

## Action Capability Contract

Every finding declares one of:

- `read_only`
- `repairable_per_row`
- `repairable_bulk`

V1 does not expose `repairable_bulk`, but the vocabulary is reserved so future checks
do not need a new top-level shape.

An unavailable action carries:

- repair key
- localized reason code
- whether the limitation comes from ownership, paid history, ambiguity, unsupported
  structure, stale data, or missing prerequisites

The UI renders an explanation, not a disabled control with no reason.

## Repair Contract

### Supported V1 repairs

| Check | Repair |
| --- | --- |
| `exchange_trio` | apply one supported canonical reference-chain correction |
| `exchange_return` | apply one supported return-percentage or corrected-value choice |
| `card_exchange_projection` | repair one unambiguous card-bound projection group |
| `misplaced_exchange_intent` | convert one owned source and active replay payloads to reimbursement |
| `piggy_bank` | none; diagnostic-only |

Other findings in a partly repairable check remain read-only with a reason.

### Preview

Preview is mandatory and read-only. It returns a normalized
`HealthCheck::RepairPreview` with:

- check key and repair key
- finding key
- validated scope
- affected record identifiers and types
- current and proposed values
- reference changes
- paid-history implications
- warnings and unavailable reasons
- generated timestamp
- deterministic digest
- signed, expiring apply token

Preview must not:

- save a financial record
- enqueue recalculation
- create an `AuditVersion`
- claim that an ambiguous choice is safe

### Confirmation and apply

Apply requires:

- administrator authorization
- the signed preview token
- explicit confirmation
- the same user/context/connected-user scope
- a fresh validation of current state

The apply service rejects a stale digest or changed record graph instead of
overwriting newer work. Each per-finding repair runs atomically. If any required
mutation, validation, synchronization, or recalculation fails, the whole repair rolls
back.

### KAKASHI-08 linkage

Every successful apply runs with root source `admin_repair`. The audit operation
metadata includes bounded scalar identifiers such as:

- health-check key
- repair key
- finding key
- preview digest

The result returns the persisted operation ID and links to its KAKASHI-08 operation
page. The repair's generated projections may refine their immediate mutation source,
but remain grouped under the same operation.

A preview creates no audit operation. A rejected apply may present its rejection in
the Health Check result without fabricating financial versions.

### Rerun

After a committed repair:

1. render the repair result through Turbo
2. enqueue the affected check with a new generation token
3. display its summary as running
4. refresh detail and summary state when the rerun finishes

Only that rerun determines the new health outcome.

## Partial Failure Contract

- A per-finding repair is atomic and reports success or failure.
- If a future bulk repair applies some candidates and skips others, its result is
  explicitly `partial`, lists both groups, and cannot render a success-only notice.
- `Run all` may finish with a mixture of healthy, warning, failing, and unavailable
  checks; the overview preserves each count.
- One unavailable check never turns the overall workspace healthy.
- A stale or conflicted preview is an expected rejection, not a silent no-op.

## Naming Convention Maintenance

Naming Convention remains separate from check status:

- preview is the default state
- apply requires explicit confirmation
- the scope is `current_context`
- the action is administrator-only
- applied changes use the `admin_repair` audit source
- the result links to an audit operation when audited financial rows changed

Naming advice does not become an artificial health warning. Its existing linter
remains authoritative, with controller/view extraction and route/locale renaming as
needed.

## Turbo and DOM Contract

- Summary, detail, result, and repair targets use string IDs beginning with
  `healthcheck_`.
- IDs that JavaScript or tests depend on are string literals in Phlex views.
- Jobs broadcast only to signed stream names scoped by user, context, and optional
  connected user.
- Turbo responses update the affected summary card, overview counters, detail frame,
  and notification stack without replacing the entire workspace.
- The generic lazy-tab behavior currently named `naming-tabs` is renamed to a neutral
  reusable concept. Balances and Naming Convention regressions must pass after the
  rename.
- Loading, empty, error, running, stale-summary, and unavailable states remain usable
  on narrow mobile layouts and in dark mode.

## Explicitly Out of Scope

- Rails process, database-connection, or infrastructure monitoring covered by `/up`
- global inspection of every user's finance data
- persisted copies of Health Check finding payloads
- historical diagnostic-run analytics
- automatic repair after a failed check
- a global `Repair all`
- new Piggy Bank repair algorithms
- new reference/invoice or balance-projection checks without an implemented runner
- backup relocation
- generic balance recalculation
- arbitrary SQL or operator-authored checks
- user preferences; KAKASHI-12 owns that product direction
