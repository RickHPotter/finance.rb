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
    - [KAKASHI-11: Prevent stale card-bound returns during reference merges](#kakashi-11-prevent-stale-card-bound-returns-during-reference-merges)
    - [KAKASHI-12: Add user profiles, preferences, and friendships](#kakashi-12-add-user-profiles-preferences-and-friendships)
    - [KAKASHI-13: Rebuild conversations around friendships](#kakashi-13-rebuild-conversations-around-friendships)
    - [KAKASHI-14: Guarantee readable category colours](#kakashi-14-guarantee-readable-category-colours)
    - [KAKASHI-15: Make Turbo navigation URL-correct](#kakashi-15-make-turbo-navigation-url-correct)
    - [KAKASHI-16: Unlock and bulk-manage category and entity allocations](#kakashi-16-unlock-and-bulk-manage-category-and-entity-allocations)
    - [KAKASHI-17: Complete and harden resource dashboards](#kakashi-17-complete-and-harden-resource-dashboards)
    - [KAKASHI-18: Improve selectors and merge categories or entities](#kakashi-18-improve-selectors-and-merge-categories-or-entities)
    - [KAKASHI-19: Harden internal and external entity ledgers](#kakashi-19-harden-internal-and-external-entity-ledgers)
    - [KAKASHI-20: Audit spec quality and application performance](#kakashi-20-audit-spec-quality-and-application-performance)
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
person-to-person transfers, and Piggy Bank savings without changing the existing
Overview or legacy balances page.

Feature scope:

- keep the existing balances Overview as the default tab and load Monthly Analysis
  only when the user first opens it
- analyze exactly one selected month with previous/next navigation and a month picker
- scope all reads to `current_context`, including derived scenarios
- attribute cash and card values by each installment's own reference month/year
- exclude budgets and generated card-payment cash rows from ordinary movement
- exclude aggregate Investment cash projections so unlinked legacy Investments do not
  enter the analysis indirectly
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
- exclude `PIGGY BANK` contributions and generated `PIGGY BANK RETURN` withdrawals
  from ordinary income/outcome
- add a separate Piggy Banks panel for paid/projected contributions and withdrawals,
  plus signed profit/loss from explicitly linked Investments
- keep unlinked legacy Investments outside the monthly analysis
- render four responsive Chart.js horizontal-bar panels for income/outcome by category
  and entity, plus accessible Transfers and Piggy Banks panels
- provide text legends and loading, error, retry, and empty states for narrow/mobile
  layouts and dark mode
- retire `/balances/legacy` and the ApexCharts dependency after the Chart.js balance
  history and monthly-analysis surfaces replace it
- expose the selected-month data through a focused finder and JSON route rather than
  extending the legacy balance payload
- cover route rendering, context isolation, monthly attribution, allocation bundles,
  transfer direction, Piggy Bank attribution, partial-payment splits, and duplicate
  prevention

References:

- [product and data contract](docs/sprints/4-kakashi/kakashi-06/01-product-and-data-contract.md)
- [implementation slices](docs/sprints/4-kakashi/kakashi-06/02-implementation-slices.md)
- [decisions and test matrix](docs/sprints/4-kakashi/kakashi-06/03-decisions-and-test-matrix.md)

### KAKASHI-07: Consolidate remaining finance datetime controls

- Issues:
  - [#50](https://github.com/RickHPotter/finance.rb/issues/50)

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

- Issues:
  - [#51](https://github.com/RickHPotter/finance.rb/issues/51)

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

- Issues:
  - [#52](https://github.com/RickHPotter/finance.rb/issues/52)

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

- Issues:
  - [#53](https://github.com/RickHPotter/finance.rb/issues/53)

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

### KAKASHI-11: Prevent stale card-bound returns during reference merges

- Issues:
  - [#54](https://github.com/RickHPotter/finance.rb/issues/54)

Type: bugfix.

Goal: make a user-card reference merge migrate its card-bound exchange rows and
resynchronize their `EXCHANGE RETURN` projections in the same operation, preventing
the stale and duplicate projection state that currently requires retrofit repair.

Root cause:

- `Logic::References.merge` moves the source invoice's `CardInstallment` rows into the
  target month/year and removes the source reference
- card-bound `Exchange` rows retain their old month, year, and date
- `ExchangeCashTransactable` therefore continues to treat the old source bucket as
  valid and leaves its projected `EXCHANGE RETURN` cash transaction in place
- the target projection does not absorb the moved source exchanges, so invoice and
  projection state diverge

Fix scope:

- wrap the complete reference merge in one database transaction
- resolve and validate adjacent source/target references and unpaid invoice projections
  before mutating either side
- keep the existing card-installment migration into the target invoice bucket
- select only monetary card-bound exchanges whose source `CardTransaction` belongs to
  the merged `UserCard` and `current_context`
- move source-bucket exchange month/year to the target bucket and derive the target
  exchange date from the target user-card reference
- synchronize affected projection cash transactions through the projection domain
  service/concern rather than changing only cash transaction columns
- make the target `EXCHANGE RETURN` absorb the moved exchanges and recalculate its
  description, price, date, month/year, installment structure, and paid state
- remove the source projection when it no longer owns monetary exchanges
- merge duplicate same-bucket projections deterministically if legacy state is already
  present when the reference merge begins
- preserve paid installment prefixes and rebuild only the editable unpaid remainder
  under the existing financial-safety rules
- update the target reference and remove the source reference only after projection
  synchronization succeeds
- recalculate balances from the earliest affected source/target date
- roll back card installments, exchange rows, projections, and references together if
  any step fails

Architecture direction:

- keep `Logic::References.merge` as the orchestration boundary, but extract exchange
  selection and projection synchronization into focused collaborators if the service
  becomes difficult to reason about
- reuse canonical grouping and synchronization rules from `ExchangeCashTransactable`;
  do not duplicate projection arithmetic in the reference service
- avoid raw `update_all` for exchange migration unless an explicit synchronization
  pass and failure strategy are guaranteed
- retain the existing audit and `Fix projection` action for historical inconsistencies;
  prevention does not repair data damaged before deployment
- record the merge through KAKASHI-08 auditing when persistent auditing is enabled

Regression coverage:

- merge adjacent source and target references containing ordinary card installments
  and card-bound monetary exchanges
- assert every affected source exchange receives the target month/year/reference date
- assert one canonical target `EXCHANGE RETURN` remains and owns exchanges from both
  previous buckets
- assert projection price and installment totals equal the sum of attached exchanges
- cover missing source/target references or invoices without partial mutation
- cover context and user-card isolation so unrelated exchanges never move
- cover an existing duplicate target projection
- cover paid source projection history, preserving the paid prefix and editable unpaid
  remainder
- cover rollback when projection synchronization fails
- assert balance recalculation begins at the earliest affected month

### KAKASHI-12: Add user profiles, preferences, and friendships

- Issues:
  - [#56](https://github.com/RickHPotter/finance.rb/issues/56)

Goal: make the user a first-class product record with server-backed preferences and an
explicit friendship lifecycle that can safely support transaction exchange,
conversations, and per-friend automation.

User profile:

- add a profile surface for display name, avatar, locale, timezone, and other public or
  account-level identity fields
- separate public profile fields from private account/security data
- expose edit/update through dedicated profile routes rather than expanding Devise
  registration behavior indiscriminately
- define what another user can see before making profiles discoverable

User preferences:

- add a one-to-one typed settings record instead of relying on browser-local state or
  an unvalidated JSON dumping ground
- support persisted defaults for theme, landing page, active context, per-index sort and
  direction, date/time presentation, default account/card, page density, and other
  repeated workflow choices as they become concrete
- let explicit URL/form state override a saved default for the current request
- synchronize theme preference with the early layout boot script so the first render
  does not flash the wrong theme
- provide reset-to-default behavior and validate every enum/value server-side
- treat automatic actionable-message acceptance as a policy, not one global checkbox:
  scope it by friend, message action/type, and context risk where appropriate
- never auto-accept destructive, paid-history, ambiguous, or validation-failing actions

Friendship model:

- replace implicit friendship through `Entity#entity_user_id` with an explicit
  user-to-user `Friendship`/request record and string-backed lifecycle states such as
  pending, accepted, rejected, blocked, and removed
- enforce one canonical relationship per user pair regardless of request direction
- support request, accept, reject, cancel, unfriend, and block actions
- create or reconcile the paired user-backed entities only after friendship acceptance
- retain stable user/entity mapping so exchanged transactions resolve to the correct
  local entity without name matching
- prevent blocked, rejected, or removed relationships from creating new shared
  transactions or conversations
- define how existing user-backed entities are backfilled without inventing friendship
  consent silently

Transaction exchange:

- authorize friend notifications and actionable transaction exchange through accepted
  friendship, not merely the presence of an entity pointing at a user
- keep sender and receiver contexts explicit and preserve current scenario-cloning rules
- expose per-friend exchange preferences, including allowed notification types and
  eligible auto-accept policies
- record request/accept/block and automatic-apply events through KAKASHI-08 auditing

Coverage and safety:

- cover profile privacy, preference precedence, invalid defaults, friendship uniqueness,
  reciprocal lookup, request races, block behavior, entity reconciliation, context
  isolation, notification authorization, and safe auto-accept denial
- index canonical user-pair lookup and avoid exposing users through enumerable IDs or
  predictable public routes

### KAKASHI-13: Rebuild conversations around friendships

- Issues:
  - [#57](https://github.com/RickHPotter/finance.rb/issues/57)

Goal: update conversation routing and lifecycle after explicit users, profiles, and
friendships exist, so direct and actionable-message conversations have canonical URLs,
participants, context scope, and permissions.

Relationship and routing:

- require an accepted friendship for new user-to-user conversations
- create or resolve one canonical direct conversation per participant pair and scenario
  instead of allowing duplicate threads from competing entry points
- distinguish direct conversations from assistant/actionable transaction threads with a
  string-backed conversation kind
- make conversation URLs stable and ensure index/show/create navigation updates browser
  history correctly under KAKASHI-15
- resolve participants through friendship/user identity rather than searching for a
  matching entity name
- deny access immediately after block/unfriend according to a documented history
  retention policy

Conversation experience:

- add friend-aware new-conversation entry, profile/avatar identity, empty states,
  unread counts, last-message summaries, and stable ordering
- add archive, mute, and read-state controls without deleting financial messages
- paginate messages and conversation lists while preserving realtime Turbo broadcasts
- keep selected context/scenario visible and prevent silent fallback to `main_context`
- provide clear links from actionable messages to the local source/return transaction
  and back to the conversation

Actionable messages:

- centralize pending, accepted, rejected, expired, failed, and unavailable states
- evaluate auto-accept through the KAKASHI-12 per-friend policy and the same validation
  path used by manual apply
- make apply idempotent and protect against duplicate delivery, stale payloads, wrong
  context, and already-mutated local references
- audit automatic and manual apply/reject actions with conversation, message, friend,
  context, and resulting transaction operation IDs

Coverage:

- cover canonical thread creation under concurrency, friendship authorization, block
  behavior, scenario isolation, unread isolation, archive/mute state, pagination,
  realtime rendering, auto-accept policy, idempotent apply, and browser URL correctness

### KAKASHI-14: Guarantee readable category colours

- Issues:
  - [#58](https://github.com/RickHPotter/finance.rb/issues/58)

Goal: guarantee that category text remains legible for every user-selected background
colour across light mode, dark mode, chips, charts, forms, indexes, and dashboards.

Colour contract:

- add an optional category text-colour preference with automatic and manual modes
- in automatic mode, calculate relative luminance and select a foreground colour that
  meets the chosen WCAG contrast threshold against the category background
- use a central Ruby colour/contrast service for persisted/rendered decisions and a
  matching lightweight client preview; do not scatter black/white guesses across views
- normalize accepted colours to one canonical hex format and reject invalid or
  transparent values where contrast cannot be guaranteed
- allow manual text colour only when it passes the minimum contrast threshold; show the
  measured contrast and suggest an accessible alternative when it fails
- backfill existing categories into automatic mode without changing their background
  colours

UI application:

- route every category chip, selector option, budget allocation, dashboard label,
  filter summary, and transaction row through one category colour helper/component
- pass resolved foreground/background colours to charts and legends without assuming
  one category colour for multi-category bundles
- provide a live light/dark preview in the category form
- keep focus rings, borders, disabled state, selected state, and hover state readable in
  addition to the normal label

Coverage:

- test very light, very dark, mid-luminance, saturated, invalid, and boundary contrast
  colours
- add view coverage proving that no category surface hardcodes an incompatible text
  colour over the resolved background

### KAKASHI-15: Make Turbo navigation URL-correct

- Issues:
  - [#59](https://github.com/RickHPotter/finance.rb/issues/59)

Goal: ensure the browser URL, history stack, rendered screen, and server resource always
describe the same location after Turbo navigation and form submission.

Navigation contract:

- use normal top-level visits and redirects when the user moves between index, new,
  show, and edit resources
- reserve Turbo Stream replacement for genuinely in-place updates, validation failures,
  modals, and nested fragments
- after successful create/update/destroy, use redirect/visit behavior that updates the
  address bar to the canonical destination instead of replacing `#center_container`
  while leaving `/new` or `/edit` behind
- preserve index filter/month/context return state through explicit parameters or a
  small navigation-state contract, not through stale browser URLs
- define consistent `advance`, `replace`, and restore behavior for create chains,
  duplicate flows, modal actions, and cancel/back actions
- ensure redirects from Turbo requests return appropriate status codes and do not cause
  double rendering or full-page content inside a frame

Audit and implementation:

- inventory every top-level link/form that targets `center_container`, requests
  `format: :turbo_stream`, or renders index content after save
- correct cash/card transactions first, including the `/new` to successful index case,
  then budgets, investments, subscriptions, dashboards, settings/healthcheck, and
  internal authenticated screens
- add a small shared responder/helper only if it makes destination and history behavior
  explicit; do not hide route decisions behind controller magic
- keep form validation failures on the current form URL with entered values and stacked
  notifications
- coordinate with KAKASHI-13 so conversation routes follow the same history rules

Regression coverage:

- add browser/system coverage for address-bar URL, rendered page, Back, Forward, refresh,
  direct deep links, successful save, failed save, cancel, duplicate, and chained entry
- cover Turbo and non-Turbo requests so progressive navigation remains valid
- treat screen/URL disagreement as a navigation regression even when the visible HTML
  appears correct

### KAKASHI-16: Unlock and bulk-manage category and entity allocations

- Issues:
  - [#60](https://github.com/RickHPotter/finance.rb/issues/60)

Goal: remove the blanket post-payment category/entity lock and provide safe, consistent
single and bulk allocation tools for cash transactions, card transactions, and budgets.

Allocation rules:

- allow descriptive category and entity corrections after payment while preserving
  immutable amount, installment, payment-date, and balance history
- replace the current all-or-nothing allocation guard with a focused allocation
  mutation service shared by normal forms and bulk actions
- keep system-owned structural categories and relationships valid: card payment,
  installment, exchange/return, subscription, Piggy Bank, and other generated families
  cannot be removed or combined into an impossible state
- coordinate structural entity changes for exchanges, shared returns, and Piggy Bank
  through their domain services rather than orphaning projections
- keep cross-user friendship authorization and local/counterpart allocation behavior
  explicit
- audit every paid-history allocation correction through KAKASHI-08

Bulk Action Bar:

- add `Add Category`, `Remove Category`, `Switch Category`, `Add Entity`, `Remove
  Entity`, and `Switch Entity` actions
- make the actions available on cash transaction, card transaction, and budget indexes
  using the same selection and eligibility contract
- show selected count, affected count, skipped count, conflicts, and the proposed source
  and destination allocation before confirmation
- define switch as idempotent replacement: add the destination when missing, remove the
  source, and avoid duplicate join rows when both already exist
- execute each submitted bulk operation atomically unless the user explicitly chooses
  a previewed eligible-only mode
- rerender affected rows and bulk eligibility without losing index state

Safety and recalculation:

- validate ownership, context, active state, built-in restrictions, category-family
  conflicts, entity uniqueness, and paid-history structural constraints server-side
- refresh budget matching/consumption and any category/entity counters or cached totals
  affected by allocation changes
- do not recalculate financial balances when only descriptive allocation changes; do
  recalculate dependent projections when a structural domain rule requires it
- provide detailed stacked failure notifications rather than one generic invalid error

Coverage:

- cover paid and unpaid rows, mixed eligibility, duplicate destinations, built-in
  categories, exchange/Piggy Bank entities, subscriptions, budgets, context isolation,
  rollback, audit events, and Turbo row refresh

### KAKASHI-17: Complete and harden resource dashboards

- Issues:
  - [#61](https://github.com/RickHPotter/finance.rb/issues/61)

Goal: finish the resource `show` surface and correct list/drill-down actions so every
dashboard explains the record and navigates to the exact related records it claims to
list.

New dashboards:

- add `InvestmentsController#show`, route, Phlex dashboard, and context-scoped lookup
- add `SubscriptionsController#show`, route, Phlex dashboard, and context-scoped lookup
- keep edit forms as mutation surfaces; show pages should explain state and provide
  guarded actions

Investment show scope:

- show investment type, account, date/reference period, principal/value, generated cash
  transaction, categories/entities, and relevant aggregation links
- expose edit, duplicate, related transaction, and guarded destroy actions where valid
- distinguish the existing Investment aggregate model from the KAKASHI-05 Piggy Bank
  transaction flow

Subscription show scope:

- show lifecycle status, description/comment, derived total, allocations, and linked
  cash/card transaction history
- separate active/future, paid/history, and detached transaction state
- expose edit, add/attach transaction, pause/finish, and guarded destroy actions

Existing show hardening:

- audit every `List`, `View all`, count, allocation, and related-record button on cash,
  card, budget, account, card, category, and entity dashboards
- make each action open an index filtered to the corresponding related records instead
  of returning to an unfiltered generic index
- add explicit filter parameters or dedicated collection endpoints when the current
  index cannot express the relationship accurately
- preserve context, date range/month, source dashboard, and return navigation
- align section naming, empty states, action placement, mobile detail rows, and generated
  transaction/reference links with KAKASHI-10

Coverage:

- cover show rendering, context isolation, action eligibility, exact list URLs, filtered
  result membership, empty relationships, generated records, and useful return paths

### KAKASHI-18: Improve selectors and merge categories or entities

- Issues:
  - [#62](https://github.com/RickHPotter/finance.rb/issues/62)

Goal: make financial selectors rank the user's intended result predictably and provide
transaction-safe category/entity consolidation directly from their indexes.

Search ranking:

- apply one normalized ranking contract to User Bank Account, User Card, Category, and
  Entity comboboxes
- rank exact match first, then starts-with, word-start, and substring matches, with a
  stable localized alphabetical tie-breaker
- normalize case, accents, punctuation, and repeated whitespace consistently between
  Ruby-rendered options and Stimulus filtering
- preserve domain-specific searchable aliases such as bank/card name, account suffix,
  entity name, and category name without letting a weak alias outrank an exact label
- ensure a query such as `SALE` orders `SALE` before `RESALE`
- keep keyboard selection, hidden-option behavior, and large-list performance stable

Category transfer and destroy:

- add a row action that selects a destination category, previews affected records,
  transfers every eligible allocation from source to destination, and removes the source
  category after verification
- include cash/card transactions, budgets, subscriptions, and other category join owners
  in the preview and transfer contract
- collapse duplicate allocations when a record already has the destination category
- protect built-in/system category families from invalid merge or destruction

Entity transfer and destroy:

- add the equivalent source-to-destination merge action for entities
- include ordinary allocations and report structural `EntityTransaction` conflicts
  separately when source and destination already occur on the same transaction
- coordinate exchanges, shared-user entities, Piggy Bank ownership, and generated
  projections through domain services rather than changing foreign keys blindly
- prevent merging user-backed friend entities when the destination represents a
  different user

Operation contract:

- run preview before apply, show eligible/conflicting/skipped counts, and require
  explicit confirmation
- apply the transfer and source destruction atomically
- recalculate counters, budget matches, projections, and affected derived data
- write one grouped KAKASHI-08 audit operation with source, destination, affected record
  IDs, conflicts, and result
- keep the source when any required allocation cannot be transferred safely

Coverage:

- test ranking tiers and normalization as well as category/entity merge ownership,
  duplicate joins, built-ins, structural conflicts, friend entities, context isolation,
  atomic rollback, counters, and audit history

### KAKASHI-19: Harden internal and external entity ledgers

- Issues:
  - [#63](https://github.com/RickHPotter/finance.rb/issues/63)

Goal: make the authenticated `/internal/:entity_slug` and public
`/:user_slug/external/:entity_slug` ledgers secure, navigable, consistent with the main
finance indexes, and maintainable without parallel route/view drift.

Identity and access:

- replace `User.all.detect` and per-request parameterized-name scans with indexed,
  stable public user/entity identifiers
- keep internal ledgers authenticated and scoped to the current user's entity/context
- replace public access based only on guessable slugs with an explicit revocable share
  grant or sufficiently strong public token
- define which transaction fields, comments, allocations, references, and totals are
  safe to expose externally; default to the minimum read-only ledger
- provide share creation, copy, expiration/revocation, and last-access visibility to the
  owner
- return not-found for invalid, revoked, cross-user, or cross-context access without
  leaking record existence

Shared ledger experience:

- converge internal/external cash and card indexes on shared presentation and index
  state while keeping authorization and route generation explicit
- provide clear owner/entity identity, scope, last-updated state, totals, paid/pending
  status, filters, ordering, month navigation, empty states, and responsive rows
- preserve internal/external route parameters through month-year lazy loads, filters,
  sorting, pagination, and browser navigation
- fix links that accidentally escape into the main authenticated routes or lose the
  entity/user scope
- keep external pages free of mutation controls, private navigation, and unrelated
  application chrome
- make internal navigation integrate with KAKASHI-15 URL/history rules

Architecture:

- replace the ambiguous `lalas` module naming with a ledger-oriented namespace when the
  route/controller migration can be performed safely
- extract shared ledger query/presentation contracts instead of continuing separate
  cash/card/internal/external copies
- keep context and entity scoping in query objects/controllers, never only in rendered
  links
- add rate limiting, non-indexing headers, and cache/privacy rules appropriate for
  public financial views

Coverage:

- cover authentication, token/share authorization, revocation, slug/token enumeration,
  field redaction, context/entity isolation, route preservation, filters, month loading,
  mobile layout, browser history, and absence of external mutation actions

### KAKASHI-20: Audit spec quality and application performance

- Issues:
  - [#64](https://github.com/RickHPotter/finance.rb/issues/64)

Goal: make the growing RSpec suite fast and predictable enough for daily use while
using slow or hanging examples to identify application paths that perform unnecessary
database, callback, projection, rendering, or notification work.

This feature must distinguish four costs before optimizing them:

1. process boot and global test setup
2. per-example factory/database setup
3. application code exercised by the example
4. cleanup, coverage reporting, browser, and external-service teardown

Measurement baseline:

- record total wall time for the full required suite and separately for models,
  concerns, requests, services, and feature/system specs
- capture Rails boot time, schema-maintenance time, SimpleCov startup/finalization, and
  time before the first example begins
- publish the slowest example groups and examples with file/line, setup time, execution
  time, database query count, factory count, and retry/wait behavior where measurable
- run repeated samples with fixed seeds to distinguish consistently slow examples from
  random contention or order dependence
- add a no-progress watchdog that reports the currently running example and useful
  thread/database diagnostics before terminating a genuine hang
- establish a checked-in benchmark report and explicit local/CI performance budgets
  only after the first repeatable baseline exists

Spec and factory audit:

- identify outdated expectations, duplicated scenarios, tests that assert framework
  behavior, and broad request examples that should be split or moved to model/service
  coverage
- preserve behavior and regression coverage; do not delete expensive specs merely to
  improve the headline count or runtime
- make factories minimal and deterministic by default, moving expensive association
  graphs and callbacks into explicit traits
- replace unnecessary `create` calls with `build`, `build_stubbed`, or direct focused
  records only when persistence is irrelevant to the behavior under test
- remove random `rand`/Faker choices from fields that affect billing dates, reference
  buckets, signs, ordering, or validation branches
- audit `custom_create`, `find_or_create`, after-create callbacks, built-in creation,
  context creation, and implicit installment/exchange graphs for repeated hidden work
- create shared setup only when it reduces real work without coupling unrelated
  examples or leaking mutable records
- keep transactional isolation and make order-dependent failures reproducible by seed

Hang and flakiness hardening:

- classify hangs as database locks, open execution sessions, network calls, jobs,
  Turbo broadcasts, mail/push delivery, browser waits, retry loops, or application
  callback recursion before applying a timeout
- block real outbound network access in tests and provide explicit adapters/fakes for
  mail, push, assistant, and external integrations
- ensure background jobs, broadcasts, and notification callbacks run in a documented
  deterministic mode per spec type
- add bounded waits and diagnostic failure messages to browser/system tests; do not
  hide application deadlocks behind larger Capybara timeouts
- make interrupted RSpec runs terminate child processes, drivers, and database sessions
  cleanly
- track flaky examples by seed and root cause instead of automatically retrying them
  into a green build

Application performance investigation:

- use slow request/service specs as entry points for query and callback profiling
- prioritize cash/card index loading, month-year endpoints, dashboard reports, context
  cloning, balance recalculation, subscription synchronization, exchange projection
  rebuilds, shared-return messages, audits/health checks, and bulk actions
- detect N+1 queries, repeated relation materialization, unbounded in-memory grouping,
  duplicate counter recalculation, and repeated rendering of unchanged Turbo fragments
- instrument expensive callbacks and cascading saves so one transaction operation can be
  attributed across installments, allocations, exchanges, messages, and projections
- batch or defer work only when transaction safety and user-visible consistency remain
  explicit
- add focused query-count or operation-count regression specs around optimized hot paths
  instead of timing assertions that will be unstable across machines

Suite architecture:

- keep `spec_helper` lightweight and load Rails only for examples that require it where
  the repository can adopt that split without excessive churn
- review whether SimpleCov should run on every focused local invocation or only when a
  coverage mode is requested, while keeping CI coverage authoritative
- separate fast correctness jobs from browser/feature and expensive operational suites
  so failures are reported earlier
- introduce parallel test workers or CI sharding only after factories, database state,
  context isolation, ports, files, and external adapters are proven parallel-safe
- balance shards using measured historical duration rather than file count
- retain an easy single-process command for reproducing order, locking, and shared-state
  failures

Developer workflow:

- add documented commands for fast smoke, changed-file/focused, required CI subset,
  full suite, profiling, and flakiness reproduction by seed
- print a concise timing summary at the end of CI and retain a machine-readable timing
  artifact for comparison
- fail clearly when `.env.test`, PostgreSQL, browser dependencies, migrations, or test
  services are unavailable instead of appearing to hang silently
- document when elevated local database access is required

Acceptance direction:

- the suite can identify the currently running example when progress stops
- the slowest examples and groups have measured explanations rather than guesses
- focused model/request runs avoid unrelated browser or external-service setup
- factory creation and database query volume decrease on the highest-cost suites
- optimized application paths gain operation/query regression coverage
- CI reports failures sooner and retains enough timing data to detect regressions
- the full required suite remains behaviorally equivalent and reproducible by seed

Explicitly out of scope:

- weakening financial assertions or safety coverage for speed
- replacing RSpec or FactoryBot before profiling proves they are the limiting factor
- blanket mocking of application internals
- arbitrary timing assertions tied to one development machine
- parallelization as a substitute for fixing deadlocks, N+1 queries, or callback storms

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
dashboards to reconciled reports and drill-down workflows. `KAKASHI-11` closes the
known reference-merge integrity gap so card-bound return projections cannot drift from
their source invoice during a merge. `KAKASHI-12` through `KAKASHI-19` establish the
next development foundation: user identity and friendships, conversation lifecycle,
accessible category colours, correct Turbo navigation, editable allocations, complete
resource dashboards, predictable selectors and merge tools, and hardened shared entity
ledgers. `KAKASHI-20` keeps that growth sustainable by profiling the spec suite,
cleaning outdated or wasteful test setup, and using slow examples to improve application
hot paths without sacrificing financial regression coverage.
