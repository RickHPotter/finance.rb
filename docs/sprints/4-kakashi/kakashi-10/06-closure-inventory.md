# KAKASHI-10 Closure Inventory

## Status

KAKASHI-10 is delivered in eight vertical slices. Its result is a connected, read-only
reporting layer on the existing resource dashboards. No new mutation workflow or
generic report-builder screen was introduced.

## Delivered Surfaces

| Surface | Query contract | Presentation |
| --- | --- | --- |
| Category show | `Reports::CategoryTrend` plus reciprocal allocation overview | shared allocation trend controls, summary, chart, lists, exact sources, and a current-context Entities pie |
| Entity show | `Reports::EntityTrend` plus reciprocal allocation overview | shared allocation trend controls, summary, chart, lists, exact sources, and a current-context Categories pie |
| Bank Account show | `Reports::BankAccountMovement` | shared trend shell plus movement family and recorded-balance context |
| User Card show | `Reports::UserCardMovement` | shared trend shell plus billing, payment-state, advance, invoice, and date detail |
| Budget show | `Reports::BudgetPerformance` | definition, actual, remaining, utilization, period completion, rules, and typed sources |
| Balances Monthly Analysis | existing KAKASHI-06 finders extended with exact sources | ordinary, transfer, failed-return, and Piggy Bank analysis |

## Shared Contracts

- `Reports::QueryState` validates and serializes bounded date, granularity, paid-state,
  direction, and sort state.
- `Reports::CanonicalRows` and `Reports::MovementClassifier` keep typed installment
  identity and special-family precedence ahead of allocation joins.
- `Reports::Drilldowns` and `Reports::SourceNavigation` generate bounded typed source
  links with sanitized return state.
- `Views::Shared::AllocationTrend` provides the common category/entity/account/card
  controls, summary cards, chart, accessible textual lists, and stable states.
- `report_presentation.mjs` owns identical lazy visibility, JSON request, stale-panel
  cleanup, and localized currency presentation used by report controllers.
- `Reports::InteractiveAllocationBreakdown` restores the category-first and
  entity-first account/card dashboards with bounded server-owned totals and points.
- Category and Entity shows retain their source-filterable reciprocal pies as
  resource-wide current-context allocation overviews. These intentionally remain
  separate from the bounded trend payload and controls.
- Financial aggregation remains server-side in integer cents. Monthly Analysis now
  receives `total_failed`; JavaScript no longer totals failed rows.

## Lifecycle Boundaries

- Category, Entity, Bank Account, User Card, and Budget bounded report payloads load
  lazily. Category and Entity reciprocal overview pies render with the owning page.
- Every controller aborts an old request and ignores a response whose sequence is no
  longer current.
- Controllers abort on disconnect.
- Allocation reports own one Chart.js instance and destroy it before replacement and
  on disconnect.
- Monthly Analysis owns four named Chart.js instances in a map and destroys each one
  before replacement and on disconnect.
- Those chart owners remain separate deliberately: a single time-series canvas and a
  keyed collection of breakdown canvases are not the same lifecycle.
- A theme mutation redraws only currently visible, already-loaded charts.

## Compatibility and Frozen Boundaries

- Existing Monthly Analysis keys remain available; exact source metadata and
  `total_failed` are additive.
- KAKASHI-06 remains the classification authority.
- KAKASHI-17 remains the navigation and sanitized-return authority.
- Cash/card creation, editing, paying, projection, exchange synchronization, and audit
  behavior are unchanged.
- Actionable-message send, receive, auto-apply, manual correction, supersession,
  read-state, and revert rules are unchanged.

## Coverage Inventory

- Query-state validation, canonical typed rows, classification, drill-down chunking,
  navigation sanitization, and source navigation have service coverage.
- Category, Entity, Bank Account, User Card, and Budget report services cover totals,
  source membership, special families, context isolation, and bounded query counts.
- Monthly Analysis service coverage reconciles ordinary, sent/received/failed
  transfers, generated returns, and Piggy Bank sources.
- Request coverage checks authentication, context scoping, validation responses, lazy
  shells, JSON contracts, and read-only behavior.
- Feature coverage checks URL restoration, accessible text, source navigation,
  Turbo return state, and dashboard rendering.
- JavaScript coverage locks shared state transitions, server error propagation, and
  localized currency spacing/sign placement.
- The full CI suite remains the mutation-regression gate for adjacent finance and
  actionable-message workflows.

## Removed Drift

- Client-side failed-transfer summation was removed in favor of a server-owned total.
- Duplicated report fetch/error parsing, lazy visibility observation, panel-state
  transitions, and currency formatting were consolidated.
- Category and Entity shows keep the reciprocal allocation pies alongside the bounded
  reports. Their payloads remain current-context scoped, source-filterable, and covered
  against cross-context leakage; category slices use the shared accessible colour
  presentation.
- Bank Account and User Card retain their interactive cross-allocation dashboards;
  their former unbounded Phlex aggregation and client-side all-group summation remain
  removed.
- Currency presentation now uses one report convention in English and Brazilian
  Portuguese.
- Chart lifecycle was consolidated only within genuinely identical ownership models;
  no generic abstraction hides materially different chart behavior.

## Verification

Automated closure gate:

```text
bin/rubocop -A
node --test spec/javascript/*_test.mjs
yarn build
bin/rspec spec/services/reports spec/services/logic/finder/monthly_analysis_json_spec.rb
bin/rspec spec/requests/balances_spec.rb spec/requests/categories_spec.rb spec/requests/entities_spec.rb
bin/rspec spec/requests/user_bank_accounts_spec.rb spec/requests/user_cards_spec.rb spec/requests/budgets_spec.rb
bin/rspec spec/features/allocation_trend_spec.rb spec/features/budget_performance_spec.rb spec/features/monthly_analysis_navigation_spec.rb
bin/ci
```

Manual closure uses [05-manual-verification.md](05-manual-verification.md).
