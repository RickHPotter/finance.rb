# KAKASHI-09 Health Check: Implementation Slices

## Delivery Strategy

Build the common contract before moving audits, and move diagnostics before repairs.
The existing Settings surface remains functional until the canonical Health Check
dashboard and first registry-backed check are ready. Remove the old controller/view
branches only after equivalent request coverage exists.

Each slice must leave one coherent route/service/view boundary. Do not combine the
route rename, every audit migration, and every repair extraction into one change.

## Slice 1: Establish the Health Check domain contract

1. Add the latest-execution persistence model and migration.
2. Add string-backed execution-state and outcome enums.
3. Add partial unique indexes for unfiltered and connected-user scopes.
4. Add bounded JSONB count validation and sanitized error-code validation.
5. Add `HealthCheck::Scope`, `HealthCheck::Result`, and the check registry.
6. Register the five locked V1 checks with metadata and placeholder adapters.
7. Add result and registry specs before wiring controllers.

Primary touchpoints:

- `db/migrate/*create_health_check_runs.rb`
- `app/models/health_check_run.rb`
- `app/services/health_check/scope.rb`
- `app/services/health_check/result.rb`
- `app/services/health_check/registry.rb`
- focused model and service specs

Acceptance criteria:

- only registered check keys can be persisted
- result counts are bounded nonnegative integers
- one latest row exists per check/user/context/connected-user scope
- a null connected-user scope cannot duplicate another null scope
- result objects are immutable and contain no Active Record instances
- the new operational row is not PaperTrail-audited

Suggested commit: `feat: establish health check contracts`

## Slice 2: Introduce the canonical administrator workspace

1. Add the administrator-only Health Check base and dashboard controllers.
2. Add canonical `/healthcheck` routes.
3. Change `/settings` into a temporary redirect.
4. Rename the Hub navigation label and path to Health Check for administrators.
5. Hide the Health Check navigation item from non-admin users.
6. Render the Overview, Financial Integrity, and Maintenance sections from registry
   metadata and latest execution rows.
7. Keep KAKASHI-08 history linked without changing ordinary-user history access.
8. Add English and Portuguese `health_check` locale namespaces.
9. Add request coverage for authentication, admin authorization, context selection,
   legacy redirect, and an empty/never-run dashboard.

Primary touchpoints:

- `config/routes.rb`
- `app/controllers/health_check/base_controller.rb`
- `app/controllers/health_check/dashboard_controller.rb`
- `app/views/health_check/dashboard/show.rb`
- summary components under `app/components/` or `app/views/health_check/`
- `app/controllers/settings_controller.rb`
- `app/controllers/concerns/tabs_concern.rb`
- `config/locales/controllers/health_check.yml`
- `config/locales/controllers/tabs.yml`
- request specs

Acceptance criteria:

- admin `GET /healthcheck` renders the selected context and five registry cards
- non-admin requests cannot discover the workspace
- `/settings` redirects and never renders the old page
- `/up` remains unchanged
- initial rendering performs no audit detail evaluation and enqueues no job
- the dashboard distinguishes `never_run` from a healthy result
- non-admin KAKASHI-08 routes keep their existing authorization behavior

Suggested commit: `feat: introduce the health check workspace`

## Slice 3: Add asynchronous run orchestration

1. Add Run all and per-check rerun routes/controllers.
2. Add a run coordinator that atomically assigns a generation token and queued state.
3. Add one Solid Queue job for registered checks.
4. Revalidate administrator, context, connected user, registry entry, and generation
   token inside the job.
5. Transition through queued, running, completed, and unavailable states.
6. Prevent duplicate queued/running jobs for the same scope.
7. Prevent stale jobs from overwriting a newer generation.
8. Broadcast summary-card and overview-count updates through signed Turbo streams.
9. Add controlled exception reporting with sanitized persisted codes.
10. Add job and request specs for independent Run all outcomes.

Primary touchpoints:

- `app/controllers/health_check/runs_controller.rb`
- `app/controllers/health_check/check_runs_controller.rb`
- `app/jobs/health_check/run_job.rb`
- `app/services/health_check/run_coordinator.rb`
- Turbo stream helpers/components
- job, service, and request specs

Acceptance criteria:

- Run all enqueues one job per eligible check and loads no detail rows
- per-check rerun affects only its latest execution row
- queued/running checks display as running
- one failed job does not cancel or mislabel the others
- stale generation completion is ignored
- authorization or missing-scope changes produce unavailable, not leaked data
- broadcasts are isolated by administrator, context, and connected-user scope

Suggested commit: `feat: run health checks asynchronously`

## Slice 4: Normalize the five diagnostic checks

Migrate one check at a time behind the registry.

### Exchange Trio and canonical reference chain

1. Pass `current_user`, `current_context`, and optional `connected_user_id`
   explicitly.
2. Restrict conversations/messages to the selected context scenario.
3. Preserve current selection projection and canonical reference analysis.
4. Normalize topology failures, reference failures, warnings, repair capability, and
   unavailable reasons into findings.

### Exchange Return

1. Preserve the existing issue-code semantics.
2. Normalize affected counts without requiring the top-level dashboard to understand
   private row hashes.
3. Preserve paid/pending detail filters.
4. Map only supported allocation findings to repair definitions.

### Card-bound Exchange Projection

1. Preserve error and warning distinctions.
2. Normalize allocation, total, bucket, duplicate, and shape findings.
3. Identify an unambiguous projection repair target where the existing controller
   repair is valid.
4. Mark ambiguous or paid-history-unsafe rows read-only with reasons.

### Misplaced loan/reimbursement intent

1. Add explicit current-context and optional connected-user scope.
2. Preserve owner-only mutation rules.
3. Normalize affected source/message counts and projected behavioral impact.

### Piggy Bank

1. Register the existing audit as a first-class context check.
2. Normalize broken relationship, source, projection, valuation, and installment
   issues.
3. Keep every V1 finding read-only with a clear diagnostic-only reason.

Primary touchpoints:

- adapters under `app/services/health_check/checks/`
- scoped changes to existing `Logic::*Audit` services
- adapter and existing audit service specs

Acceptance criteria:

- every adapter returns the same result contract
- zero rows becomes healthy rather than unavailable
- Card Projection warning-only data becomes warning, not failing
- any failure finding wins over warnings in the check outcome
- Piggy Bank appears in Overview and Financial Integrity
- Exchange Trio and misplaced intent cannot read another scenario/context
- connected-user filtering cannot expose an unrelated conversation
- existing financial audit service regression specs continue to pass

Suggested commits:

- `feat: normalize exchange health checks`
- `feat: normalize projection and piggy bank checks`

## Slice 5: Add lazy, paginated finding details

1. Add one registry-backed details controller.
2. Add a shared bounded page object or reuse the compatible KAKASHI-08 pagination
   contract without coupling Health Check authorization to audit-history queries.
3. Add per-check detail presenters/components.
4. Preserve domain-specific information while sharing status, scope, action, empty,
   error, and pagination chrome.
5. Move issue-bucket loading behind check detail providers.
6. Label latest-summary time separately from live-detail evaluation time.
7. Add deterministic ordering and maximum page size.
8. Add query-count coverage for allocation/reference-heavy examples.

Primary touchpoints:

- `app/controllers/health_check/checks_controller.rb`
- `app/services/health_check/page.rb`
- `app/services/health_check/checks/*_details.rb`
- shared and check-specific Phlex components/views
- request, service, and performance specs

Acceptance criteria:

- initial dashboard HTML contains no finding rows
- opening one check evaluates no unrelated check
- pages default to 25 and cap at 100
- equal timestamps/statuses use stable record IDs as tiebreakers
- live details disclose when they are newer than the persisted summary
- filters and pagination retain context and connected-user scope
- empty, unavailable, and failed detail states are distinct

Suggested commit: `feat: lazy load health check findings`

## Slice 6: Build the repair preview framework

1. Add a repair registry under each check entry.
2. Add immutable preview/change/result value objects.
3. Add signed, expiring preview tokens with a deterministic digest.
4. Add a focused preview controller.
5. Revalidate scope and finding eligibility before previewing.
6. Extract canonical reference-chain planning behind the preview contract.
7. Extract Exchange Return allocation calculations from the controller.
8. Extract card-bound projection diagnosis and repair planning from
   `CashTransactionsController`.
9. Add misplaced-intent planning without changing records.
10. Render affected records, before/after values, references, warnings, and paid-history
    implications.

Primary touchpoints:

- `app/services/health_check/repairs/registry.rb`
- `app/services/health_check/repairs/preview.rb`
- `app/services/health_check/repairs/preview_token.rb`
- check-specific repair planners
- `app/controllers/health_check/repair_previews_controller.rb`
- preview Phlex views/components
- service and request specs

Acceptance criteria:

- every visible apply action begins with a preview
- preview creates no financial mutation, version, recalculation, or job
- ambiguous, stale, foreign, and paid-history-unsafe findings explain why apply is
  unavailable
- repeated previews over unchanged state produce the same digest
- changing a relevant record changes or invalidates the digest
- Piggy Bank never exposes a repair route or dead apply control

Suggested commit: `feat: preview health check repairs`

## Slice 7: Apply, audit, and rerun supported repairs

1. Add the focused repair apply controller.
2. Require explicit confirmation and a valid preview token.
3. Apply one finding atomically through its focused service.
4. Rebuild and compare the preview under lock before mutation.
5. Run canonical validations, paid-history rules, synchronization, and recalculation.
6. Record successful financial mutations as one KAKASHI-08 `admin_repair` operation
   with bounded Health Check metadata.
7. Link the result to the audit operation.
8. Reject stale/conflicted previews with no partial mutation.
9. Enqueue the affected check after commit and update its summary/detail state through
   Turbo.
10. Keep mixed or partial results explicit if an existing domain runner can skip part
    of a requested change.

Repair extraction requirements:

- canonical reference changes remain delegated to
  `Logic::ExchangeChainReferenceRunner`
- misplaced intent remains delegated to a focused service derived from
  `Logic::MisplacedLoanExchangeAudit`
- return percentage/value mutation leaves `Admin::SettingsController`
- card-bound projection mutation leaves `CashTransactionsController`; the transaction
  detail action reuses the extracted service

Acceptance criteria:

- successful apply creates a linked `admin_repair` operation and audit versions
- preview itself creates no operation/version
- repair metadata identifies check, repair, finding, and preview digest
- a failed mutation rolls back the full finding repair
- a stale token or diverged graph does not overwrite current data
- the post-apply check enters running and only its rerun can report healthy
- the legacy cash-transaction projection action retains behavior through the extracted
  service

Suggested commit: `feat: apply audited health check repairs`

## Slice 8: Move and harden Naming Convention maintenance

1. Move Naming Convention routes/controller/view under Health Check maintenance.
2. Require administrator authorization.
3. Keep dry-run preview as the default.
4. Add explicit confirmation and audited `admin_repair` linkage for apply.
5. Keep Naming results outside Health Check status counts.
6. Rename `settings_*` frame IDs and locale namespaces.
7. Rename `naming-tabs` to a neutral lazy-tabs concept wherever it is still needed.
8. Update balances and Naming Convention regressions for the generic controller name.
9. Remove dead Settings views/routes/locales after coverage proves parity.

Acceptance criteria:

- non-admin users cannot run naming preview or apply
- Naming preview remains read-only
- Naming apply is auditable and links to its operation when changes occur
- Naming advice never changes a health status
- balances lazy tabs still load once and retain state
- no Health Check route, frame ID, locale, controller, or view namespace uses
  `settings_*`
- the oversized `Admin::SettingsController` is removed

Suggested commit: `cleanup: retire the settings audit surface`

## Slice 9: Hardening and manual verification

1. Run focused model, service, job, request, and JavaScript/build checks.
2. Run `bin/rubocop -A` after each code-edit batch.
3. Verify queue retries, stale generations, simultaneous reruns, and scope changes.
4. Verify one check unavailable while the others finish.
5. Measure summary and detail query counts with representative large audit sets.
6. Verify English and Portuguese copy.
7. Verify dark/light themes and narrow/desktop layouts.
8. Verify Turbo restoration after browser back/forward navigation.
9. Verify `/settings` redirect and `/up` separation in deployed routing.
10. Remove temporary compatibility code that is not part of the documented redirect.

Acceptance criteria:

- CI-covered models, concerns, and requests remain green
- Health Check job specs do not depend on inline-only execution
- no cross-context, cross-user, or cross-stream data appears
- no Health Check repair can bypass preview, confirmation, administrator authorization,
  or auditing
- the owner-authorized cash-transaction projection fix remains the documented V1
  exception outside Health Check and continues through the extracted service
- summary cards render without evaluating detail collections
- large result pages remain bounded and deterministic

Suggested commit: `spec: harden health check workflows`

## Verification Commands

Before each RSpec command, load `.env.test`, or `.env` only when `.env.test` does not
exist. Run RSpec with the required PostgreSQL permissions.

Focused progression:

```sh
bin/rspec spec/models/health_check_run_spec.rb
bin/rspec spec/services/health_check
bin/rspec spec/jobs/health_check
bin/rspec spec/requests/health_check
bin/rspec spec/services/logic/exchange_trio_audit_spec.rb
bin/rspec spec/services/logic/exchange_return_audit_spec.rb
bin/rspec spec/services/logic/card_exchange_projection_audit_spec.rb
bin/rspec spec/services/logic/misplaced_loan_exchange_audit_spec.rb
bin/rspec spec/services/logic/piggy_bank_audit_spec.rb
bin/rspec spec/requests/cash_transactions_spec.rb
yarn build
```

Final verification:

```sh
bin/ci
```

## Expected Final Removal/Rename Inventory

Remove or replace after parity exists:

- `Admin::SettingsController`
- `Views::Settings::Show`
- `Views::Admin::Settings::*`
- admin settings audit routes/helpers
- health-related `settings.*` locale keys
- `settings_*` Turbo frame IDs
- `naming-tabs` registration and data attributes

Keep:

- temporary `SettingsController#show` redirect
- underlying `Logic::*Audit` services where their algorithms remain authoritative
- KAKASHI-08 audit-history routes and ordinary-user authorization
- Rails `/up`
- backup download in its current location
