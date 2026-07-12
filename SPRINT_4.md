# SUMMARY

<!--toc:start-->
- [SUMMARY](#summary)
  - [INTRODUCTION](#introduction)
  - [SPRINT IV: KAKASHI](#sprint-iv-kakashi)
    - [KAKASHI-01: Stabilize the post-Jiraiya application](#kakashi-01-stabilize-the-post-jiraiya-application)
    - [KAKASHI-02: Repair shared exchange and reference integrity](#kakashi-02-repair-shared-exchange-and-reference-integrity)
    - [KAKASHI-03: Refine budgets, reminders, and the visual system](#kakashi-03-refine-budgets-reminders-and-the-visual-system)
    - [KAKASHI-04: Expand exchange audits and correction tooling](#kakashi-04-expand-exchange-audits-and-correction-tooling)
    - [KAKASHI-05: Create the Piggy Bank flow](#kakashi-05-create-the-piggy-bank-flow)
    - [KAKASHI-06: Add balances monthly analysis](#kakashi-06-add-balances-monthly-analysis)
    - [KAKASHI-07: Consolidate remaining finance datetime controls](#kakashi-07-consolidate-remaining-finance-datetime-controls)
    - [KAKASHI-08: Add persistent financial auditing and guarded rollback](#kakashi-08-add-persistent-financial-auditing-and-guarded-rollback)
    - [KAKASHI-09: Reshape settings into a health-check workspace](#kakashi-09-reshape-settings-into-a-health-check-workspace)
    - [KAKASHI-10: Connect and evolve finance dashboards](#kakashi-10-connect-and-evolve-finance-dashboards)
  - [CONCLUSION](#conclusion)
<!--toc:end-->

## INTRODUCTION

Sprint 3 leaves the application functionally broad, but the next sprint should make
that breadth easier to trust. The main opportunities are post-Jiraiya stabilization,
stronger shared exchange and reference integrity, better operational audits, more
coherent budget and reminder surfaces, and the next finance-analysis workflows.

Kakashi should combine focused correction work with two new product directions: a
first-class Piggy Bank flow and a single-month balances analysis. The goal is not to
reopen Jiraiya, but to build deliberately on top of its accepted foundation.

## SPRINT IV: KAKASHI

### KAKASHI-01: Stabilize the post-Jiraiya application

- Issues:
  - [#44](https://github.com/RickHPotter/finance.rb/issues/44)

Goal: clean up likely regressions and maintenance debt around the Sprint 3 merge.

Planned scope:

- make cash transaction index state deterministic and add focused service coverage
- correct subscription/card synchronization edge cases
- make removal of the `SUBSCRIPTION` category detach both cash and card transactions
  from their subscription, with model coverage
- update Ruby gems and JavaScript packages together
- keep modal stacking above other application overlays

### KAKASHI-02: Repair shared exchange and reference integrity

- Issues:
  - [#45](https://github.com/RickHPotter/finance.rb/issues/45)

Goal: make exchange-return behavior survive shared-user updates, partial history,
category removal, and user-card reference merges without leaving stale projections or
counterpart records.

Planned scope:

- resolve loan-type shared `EXCHANGE RETURN` actionable messages against the correct
  local reference
- preserve canonical references during shared paid-state and structural updates while
  preventing unsafe paid-history rewrites
- diagnose and repair card-bound exchange-return projections affected by a user-card
  reference merge from the cash transaction detail screen
- move stale exchange rows to the correct billing bucket, merge duplicate same-bucket
  projections, and resynchronize the surviving projection
- preserve paid card-bound exchange history across user-card merges
- allow the entity exchange sheet to reduce exchange count and clean up the unpaid
  mirrored return structure correctly
- emit a destroy actionable message for the friend-side return when `EXCHANGE` is
  removed from a shared card transaction
- add focused concern, model, request, and audit coverage for these cases

Detailed implementation reference:

- [NBNK card-bound exchange-return analysis](docs/bugs/01_nbnk_reference_merge_card_bound_exchange_return_analysis.md)

The immediate repair path should support already-inconsistent historical projections.
The preventive path belongs in `Logic::References.merge`: reference merges should
migrate affected card-bound exchange rows and synchronize their projections during the
merge itself.

### KAKASHI-03: Refine budgets, reminders, and the visual system

- Issues:
  - [#46](https://github.com/RickHPotter/finance.rb/issues/46)

Goal: improve daily operational surfaces while making the dark interface consistent
across forms, dashboards, audits, and mobile navigation.

Planned scope:

- give budget forms and indexes clearer controls, value helpers, bulk-selection
  behavior, transaction navigation, and request coverage
- add the budget-related entry points required in cash transaction views
- expose more useful installment detail in Due Payments reminder email rows
- apply a Neovim-inspired dark palette across shared components, finance forms,
  indexes, dashboards, admin audits, sheets, charts, and mobile views
- centralize theme behavior in a dedicated Stimulus controller and apply it to chart
  and dashboard rendering as well as static controls

### KAKASHI-04: Expand exchange audits and correction tooling

- Issues:
  - [#47](https://github.com/RickHPotter/finance.rb/issues/47)

Goal: turn operator-visible exchange inconsistencies into explicit, reviewable, and
tested correction workflows.

Planned scope:

- record an explicit friend-notification intent on cash exchange sources to distinguish
  loan from reimbursement behavior
- add a loan-return percentage to entity allocations for form and audit use
- let the entity sheet calculate, reset, and match return percentages without losing
  the underlying integer-cent transaction contract
- broaden Exchange Return Audit detection and correction coverage for category, entity,
  source, projection, intent, and amount inconsistencies
- expand Card Exchange Projection Audit and Exchange Trio Audit alongside the return
  audit
- add a dedicated misplaced-loan exchange audit and operator correction screen
- expose dry-run and correction workflows through admin settings routes and actions,
  with localized result feedback
- add extensive request, model, concern, message, and service regression coverage

### KAKASHI-05: Create the Piggy Bank flow

- Issues:
  - [#48](https://github.com/RickHPotter/finance.rb/issues/48)

Goal: replace ambiguous new uses of the `INVESTMENT` category with a linked pair of
cash transactions while leaving all existing investment rows and projections intact.

Locked V1 direction:

- both `PIGGY BANK` and `PIGGY BANK RETURN` are `CashTransaction` records
- a source has exactly one entity; it is expected to be a bank, but V1 does not
  validate entity type or entity/account correspondence
- the generated return inherits the source `user_bank_account_id`
- a dedicated `PiggyBank` record links the source and return cash transactions
- the source price is strictly negative and the return price is strictly positive
- the entity sheet asks for an expected return date and amount, defaulting the amount
  to the opposite of the source price
- the return starts with one installment and uses the existing partial-pay split flow
  for early withdrawals
- paid and remaining installments must survive later source saves without projection
  collapse
- bank lockups, penalties, yield, profit, and loss calculation are outside V1
- existing `INVESTMENT` records are not renamed, classified, migrated, or audited
- exchange-family and piggy-bank-family categories cannot coexist

References:

- [domain design](docs/sprints/4-kakashi/kakashi-05/01-domain-design.md)
- [implementation slices](docs/sprints/4-kakashi/kakashi-05/02-implementation-slices.md)
- [decisions and test matrix](docs/sprints/4-kakashi/kakashi-05/03-decisions-and-test-matrix.md)

### KAKASHI-06: Add balances monthly analysis

- Issues:
  - [#49](https://github.com/RickHPotter/finance.rb/issues/49)

Goal: add a lazy-loaded `Monthly Analysis` tab to `/balances` so one selected month
can be understood through income, outcome, category allocation, entity allocation,
and person-to-person transfers without changing the existing Overview or legacy
balances page.

Feature scope:

- keep the existing balances Overview as the default tab and load Monthly Analysis
  only when the user first opens it
- analyze exactly one selected month with previous/next navigation and a month picker
- scope all reads to `current_context`, including derived scenarios
- attribute cash and card values by each installment's own reference month/year
- exclude budgets and generated card-payment cash rows from ordinary movement
- build deterministic category and entity bundles so transactions with multiple
  allocations are counted once rather than duplicated
- place rows without categories or entities in a localized `Unassigned` bucket
- separate positive income from negative outcome while presenting outcome as an
  absolute value in charts
- classify `EXCHANGE`, `EXCHANGE RETURN`, and `BORROW RETURN` as transfers instead of
  ordinary income/outcome
- aggregate transfers from monetary `Exchange#price`, preserving sent/received entity
  direction and each exchange's own month/year
- show `FAILED LEND/BORROW RETURN` separately using the neglected installment's
  `starting_price`
- render four responsive Chart.js horizontal-bar panels for income/outcome by category
  and entity, plus an accessible Transfers panel
- provide text legends and loading, error, retry, and empty states for narrow/mobile
  layouts and dark mode
- keep `/balances/legacy` untouched as the only ApexCharts balances surface
- expose the selected-month data through a focused finder and JSON route rather than
  extending the legacy balance payload
- cover route rendering, context isolation, monthly attribution, allocation bundles,
  transfer direction, and duplicate prevention

### KAKASHI-07: Consolidate remaining finance datetime controls

Goal: finish the Jiraiya datetime-input migration so transaction-specific nested rows
and actions use the same app-controlled date/time contract as the main cash/card forms
and payment/transfer modals.

Planned surfaces:

1. Nested cash and card installments
   - replace the raw `datetime-local` field in `Views::Installments::Fields`
   - retain `reactive-form` date targets, automatic schedule updates, month/year
     synchronization, and cash paid-state behavior
   - preserve locked/paid installment behavior and exact nested parameter submission

2. Nested exchanges in the entity sheet
   - replace the raw `datetime-local` field in `Views::Exchanges::Fields`
   - preserve previous/next month actions and `updateReferenceMonthYear`
   - keep standalone exchange dates editable
   - keep card-bound exchange dates read-only while allowing their derived value to be
     submitted and refreshed from the selected card reference
   - preserve exchange-lock and paid-history behavior

3. Card pay-in-advance modal
   - replace its remaining raw `datetime-local` field with
     `Views::Shared::DatetimeInput`
   - retain autofocus and the current minimum/maximum payment-date constraints
   - align mobile calendar/clock behavior with the other payment modals

Shared control work:

- add a compact repeated-row presentation to `Views::Shared::DatetimeInput` rather
  than embedding the full main-form layout inside every installment or exchange row
- support a read-only visible state that still submits the hidden canonical datetime
  value required by card-bound exchanges
- add minimum-datetime support alongside the existing maximum-datetime contract so
  pay-in-advance retains both ends of its allowed payment window
- allow existing target classes, data attributes, and Stimulus actions to remain on
  the canonical hidden input or the appropriate visible date/time control
- use unique string DOM IDs derived from the nested form index so repeated controls do
  not produce duplicate IDs
- keep parsing, 24-hour normalization, weekday feedback, and hidden-field synchronization
  inside `datetime-input_controller.js`
- align transaction submission skeletons if the compact control changes nested-row
  dimensions on mobile

Regression coverage:

- cash and card transaction requests continue to persist nested installment dates
- changing a source date continues to update eligible unpaid installment dates
- standalone exchange date changes continue to update exchange month/year
- card-bound exchanges continue to derive their date from the user-card reference and
  submit it without becoming user-editable
- locked or paid installment/exchange history remains protected
- duplicate and failed-validation rerenders preserve entered date and time values
- desktop and mobile repeated rows remain compact and free of overlapping controls

Explicitly out of scope:

- date-range search filters
- subscription recurrence date-only fields
- user-card and reference date-only administration
- changing any financial date, billing-cycle, payment, or paid-history semantics

### KAKASHI-08: Add persistent financial auditing and guarded rollback

Goal: record who changed financial data, what changed, when it changed, and which
application operation caused it, so debugging no longer depends only on current state
and selected mistakes can be reversed safely.

This feature is distinct from the existing exchange audit services. Existing audits
detect inconsistencies in the current graph; persistent auditing records the history
that produced that graph.

Foundation:

- adopt an established Rails record-versioning library after confirming Rails 8.1 and
  Ruby 4 compatibility; prefer a version model that supports immutable changesets and
  reification rather than building callback serialization from scratch
- store create, update, and destroy events in an append-only audit table
- capture actor user, context, request ID, operation ID, timestamp, record type/ID,
  event type, before/after changes, and an application-defined mutation source
- distinguish mutations originating from normal UI/API requests, assistant messages,
  shared-return synchronization, projection callbacks, admin repairs, imports,
  background jobs, and console/unknown sources
- group every cascading save from one user action under the same operation ID so a
  source transaction, installments, allocations, exchanges, and generated projections
  can be inspected as one event
- make audit writes participate in the business transaction while preventing normal
  application code from updating or deleting audit history

Initial audited scope:

- `CashTransaction` and `CardTransaction`
- cash/card installments
- category and entity transaction allocations
- `EntityTransaction` and `Exchange`
- `Reference`, `UserCard`, and `UserBankAccount` changes that affect financial routing
- `Budget`, `Subscription`, and `Investment`
- `PiggyBank` and its generated return flow when KAKASHI-05 is introduced

Debugging surface:

- add a chronological history panel for an individual financial record
- show human-readable attribute changes while retaining access to the raw changeset
- link related versions by operation ID and reference chain
- expose actor, context, mutation source, request ID, and related records
- allow filtering by record type, record ID, operation ID, actor, context, event, source,
  and date range
- make destroyed records discoverable without restoring them automatically

Guarded rollback:

- treat rollback as a new compensating operation, never as deletion of audit history
- provide a dry-run preview showing every record and attribute that would change
- reject rollback when the current record has diverged from the selected version unless
  the conflict is resolved explicitly
- restore a complete operation only when its dependent graph can be validated; do not
  silently reify one parent while leaving installments or projections inconsistent
- run normal model validations, ownership/context checks, financial safety rules, and
  authorization during rollback
- require explicit confirmation for paid-history corrections and keep prohibited
  reversals prohibited
- apply accepted rollback operations atomically, then recalculate affected balances,
  counters, references, and projections from the earliest changed date
- record the rollback itself with its source operation/version IDs and result

Operational requirements:

- define retention, indexing, payload-size, and sensitive-field redaction policies
  before enabling broad model coverage
- prevent auditing callbacks from creating recursion or duplicating versions during
  projection synchronization
- add request and model coverage for actor/context capture, grouped operations,
  create/update/destroy history, failed-save rollback, conflict detection, paid-history
  denial, successful compensation, and balance recalculation
- provide an admin-only first release; user-facing history can be considered separately

Explicitly out of scope:

- arbitrary database time travel
- bypassing validations or financial safety guards
- automatic rollback based only on a failed health check
- storing secrets, encrypted credentials, session data, or unrelated authentication
  payloads in changesets

### KAKASHI-09: Reshape settings into a health-check workspace

Goal: replace the current `/settings` audit-tab collection with a coherent application
health workspace where an administrator can see current data integrity, understand each
problem, preview a correction, apply supported repairs, and verify the result.

Product direction:

- rename the user-facing maintenance surface from Settings to Health Check
- introduce `/healthcheck` as the canonical route and keep `/settings` as a temporary
  redirect so saved links do not break
- keep Rails' infrastructure-level `/up` endpoint separate; this feature reports
  application and financial-data health rather than process availability
- keep the workspace admin-only and scoped explicitly to the selected context and any
  intentionally connected user
- move genuine user preferences elsewhere if settings/preferences are introduced later

Workspace structure:

1. Overview
   - summarize healthy, warning, failing, running, and unavailable checks
   - show the selected context, connected-user scope, last run time, duration, and
     affected-record counts
   - provide `Run all` and per-check rerun actions without loading every detailed row

2. Financial integrity
   - Exchange Trio and canonical reference-chain health
   - Exchange Return health
   - Card-bound exchange projection health
   - misplaced loan/reimbursement intent health
   - reference/invoice and balance-projection checks as those checks become available

3. Maintenance tools
   - keep Naming Convention analysis available, but separate it visually from health
     failures because naming advice is not data corruption
   - reserve explicit sections for backups, recalculation, or other operator tools only
     when they expose a real action and result

Check contract:

- give every check a stable key, title, description, severity, scope, result counts,
  last-run metadata, and supported actions
- normalize service results into a common health-check result object rather than making
  the top-level view understand each audit's private hash shape
- lazy-load details and paginate large result sets
- distinguish diagnostics from repair capability: a check may be informative,
  repairable per row, repairable in bulk, or deliberately read-only
- show why an action is unavailable instead of rendering a dead control

Repair workflow:

- make dry-run preview the default for every destructive or structural correction
- show the records, references, values, and paid-history implications before applying
  a repair
- require explicit confirmation and authorization for apply actions
- apply repairs through focused services, not through an expanding health-check
  controller
- rerun the affected check after apply and update its summary/detail state through
  Turbo
- link every repair to its KAKASHI-08 audit operation so the cause and result remain
  traceable and an eligible compensating rollback can be considered
- provide clear partial-failure reporting; never present a mixed result as fully healthy

Architecture hardening:

- replace the oversized `Admin::SettingsController` with a health-check dashboard
  controller plus focused controllers/services for individual check and repair actions
- rename Phlex views, Turbo frame IDs, locale namespaces, routes, and tab-controller
  concepts away from `settings_*` and `naming-tabs` where they now represent health
  checks
- preserve the existing exchange audit logic where it is correct; this is a second
  organization and actionability pass, not a rewrite of every audit algorithm
- add a registry that makes new checks discoverable without adding another bespoke tab
  branch to the top-level view
- cover admin authorization, context isolation, lazy loading, result normalization,
  dry-run/apply/rerun flows, unavailable actions, partial failures, and legacy route
  redirection

Acceptance direction:

- an administrator can identify the app's current financial-health status from the
  first screen
- every visible failure either has a documented repair action or clearly states why it
  is diagnostic-only
- supported repairs can be previewed, applied, audited, and rerun without leaving the
  workspace
- adding another health check does not require expanding one monolithic controller and
  one monolithic tab view

### KAKASHI-10: Connect and evolve finance dashboards

Goal: turn the existing detail dashboards into a connected analysis layer where users
can move from a summary or chart to the financial records that explain it, compare the
dimensions used in daily decisions, and retain context while navigating between views.

Dashboard navigation:

- define a consistent link matrix between cash transactions, card transactions,
  budgets, subscriptions, bank accounts, user cards, categories, entities, references,
  and generated return/projection records
- make category, entity, account, card, subscription, budget, and reference labels link
  to their respective dashboards when a meaningful destination exists
- add clear parent/child navigation for source transactions, installments, exchanges,
  generated returns, card invoices, and reference chains
- preserve selected context, month/date range, active filters, and a useful return path
  when moving from indexes to dashboards and between related dashboards
- avoid dead-end dashboards and duplicate navigation actions with different behavior

Workflow-driven reports:

1. Category and entity trends
   - show income and outcome across a selected date range
   - preserve deterministic category/entity bundle semantics so multi-allocation rows
     are counted once
   - allow a trend point or breakdown row to open the matching transaction index

2. Account and card movement
   - explain movement, paid/pending state, and balance contribution for one bank account
     or user card over the selected range
   - keep card charge date, billing reference, invoice, advance, and payment semantics
     distinct rather than flattening them into one date

3. Budget performance
   - compare budget definition, actual matched consumption, remaining value, and period
     completion
   - link every reported amount back to the matched cash/card rows used by the budget
     calculation

4. Transfer and return flows
   - provide navigable summaries for exchanges, exchange returns, borrow returns, and
     Piggy Bank returns without presenting transfers as ordinary income/outcome
   - reuse the transfer semantics established by KAKASHI-06

Shared reporting contract:

- scope every dashboard and report to `current_context`
- use explicit URL state for date range, granularity, paid state, category/entity,
  account/card, and sort direction where relevant
- put aggregation in focused finder/report services rather than Phlex views or
  Stimulus controllers
- make source-row identity explicit before grouping so joins cannot duplicate totals
- require displayed totals and chart series to reconcile with the drill-down records
- use consistent signed-value, currency, date, status, and allocation-bundle semantics
  across dashboards
- reuse KAKASHI-06 monthly-analysis primitives where their data contract matches;
  avoid creating a second incompatible chart payload

Chart and breakdown refinement:

- standardize titles, totals, legends, tooltips, ordering, colors, empty states, and
  loading/error behavior across dashboard charts
- make charts supplementary to accessible text summaries and drill-down lists
- use stable dimensions and responsive constraints so legends, labels, and loading
  states do not shift or overlap the surrounding dashboard
- preserve calm deterministic colors, with neutral treatment for multi-category bundles
- lazy-load expensive reports and cancel or ignore stale responses when filters change
- add comparison or visualization types only when they answer a named workflow; do not
  add charts solely to fill dashboard space

Implementation order:

1. audit the current dashboard link matrix and inconsistent filter/return-state behavior
2. add shared report/query-state and drill-down contracts
3. connect existing dashboards before creating new report pages
4. deliver one report at a time, starting with the workflow that has the clearest daily
   use and reconciliation rule
5. standardize charts after the underlying report contracts are stable

Regression and performance requirements:

- cover context isolation and cross-context not-found behavior
- verify every report total against its source records, including multi-allocation and
  generated-transaction cases
- cover drill-down URLs and restoration of date/filter state
- prevent N+1 allocation/reference loading and bound selected-range queries
- keep mobile/PWA dashboards readable without hiding the text equivalent of a chart
- preserve existing edit, duplicate, pay, and guarded-destroy actions

Explicitly out of scope:

- a free-form query language
- arbitrary user-authored report builders
- background data warehouses or duplicated analytics persistence
- predictive forecasting or investment recommendations
- replacing detail dashboards with marketing-style overview pages

## CONCLUSION

Kakashi should leave the application more predictable after Jiraiya: subscription and
shared-return behavior should be safer, card-bound projection damage should be both
preventable and repairable, operational audits should lead to explicit corrections,
and budgets, reminders, and dark-mode surfaces should feel coherent.

The sprint should also establish new product capabilities without mixing their domain
rules into exchange behavior: `KAKASHI-05` introduces linked Piggy Bank cash flows,
`KAKASHI-06` introduces context-aware monthly balances analysis, and `KAKASHI-07`
finishes the shared datetime-entry contract. `KAKASHI-08` makes financial mutations
traceable and selectively reversible, while `KAKASHI-09` turns the maintenance surface
into an actionable health-check workspace. `KAKASHI-10` connects the existing detail
dashboards to reconciled reports and drill-down workflows. The remaining follow-ups
stay optional until product evidence brings them into scope.
