# KAKASHI-06 Balances Monthly Analysis: Implementation Slices

## Delivery Strategy

Implement the feature from the data contract outward. Each backend slice must leave a
reconcilable selected-month payload with focused specs. Do not apply either historical
stash wholesale; both attempts contain useful ideas, but their code predates current
repository changes and each embeds rejected or incomplete behavior.

Keep the existing Balance History functional after every slice. The new route may
exist before the tab is linked, but `/balances` and `/balances/legacy` must remain
stable throughout.

## Slice 1: Ordinary Monthly Finder

1. Add `Logic::Finder::MonthlyAnalysisJson` with explicit `user:`, `context:`, and
   `month:` inputs.
2. Parse only `YYYY-MM`; expose a controlled invalid-month result rather than falling
   back silently.
3. Load selected-month cash and card installments from `current_context`.
4. Exclude generated card-payment cash rows.
5. Exclude `Investment` aggregate cash projections; do not let an unlinked legacy
   Investment enter through its generated CashTransaction.
6. Eager-load parent transactions and category/entity allocations without using joins
   as the source-value relation.
7. Exclude transfer-classified and failed-return parents from ordinary aggregation.
8. Build category and entity bundle signatures from ordered allocation IDs.
9. Add the full installment amount once to each dimension.
10. Add localized `Unassigned` bundles for missing allocations.
11. Aggregate in cents, separate income/outcome, calculate ordinary net, and serialize
    major currency units only at the response boundary.

Primary touchpoints:

- `app/services/logic/finder/monthly_analysis_json.rb`
- `spec/services/logic/finder/monthly_analysis_json_spec.rb`
- `config/locales/controllers/static/balances.yml`

Acceptance criteria:

- category total equals the selected month's ordinary installment total
- entity total equals that same ordinary installment total
- one multi-category or multi-entity installment is counted once per dimension
- allocation order produces deterministic keys and labels
- cash and card installments use their own month/year
- card-payment cash projections and transfer sources are absent
- main and derived contexts cannot see one another's records

## Slice 2: Transfer and Failure Payload

1. Load selected-month cash installments carrying `EXCHANGE`, `EXCHANGE RETURN`, or
   `BORROW RETURN` from the current context.
2. Load selected-month card installments carrying `EXCHANGE` from the current
   context.
3. Classify `EXCHANGE` and `BORROW RETURN` as sent and `EXCHANGE RETURN` as received.
4. Aggregate by deterministic entity bundle and direction.
5. Serialize separate sent and received totals without netting.
6. Load `FAILED LEND/BORROW RETURN` cash installments from the selected context and
   month.
7. Aggregate their absolute `starting_price` by deterministic entity bundle.
8. Keep failed values separate from sent, received, income, and outcome totals.
9. Return empty arrays/totals safely when no eligible installments exist.

Primary touchpoints:

- `app/services/logic/finder/monthly_analysis_json.rb`
- `spec/services/logic/finder/monthly_analysis_json_spec.rb`

Acceptance criteria:

- each eligible installment contributes once using its own price
- source and return installment month/year independently select each side
- category produces the expected sent/received direction
- a June `EXCHANGE` source with a July `EXCHANGE RETURN` installment appears only in
  July Received
- failed returns use installment `starting_price`
- a transfer parent never reappears in ordinary bundles
- context isolation holds through context-owned installments

## Slice 3: Piggy Bank Savings Payload

1. Identify context-owned `PIGGY BANK` source cash transactions and generated
   `PIGGY BANK RETURN` transactions.
2. Exclude both families from ordinary and transfer aggregation.
3. Attribute contributions by each source cash installment's month/year, amount, and
   paid state.
4. Resolve every contribution to its authoritative return-group ID through
   `PiggyBank` links.
5. Attribute withdrawals by each return cash installment's month/year.
6. Split both contribution and withdrawal totals into paid/realized and
   unpaid/projected values.
7. Load only `Investment` rows with a `piggy_bank_return_cash_transaction_id` in the
   current context and selected month.
8. Aggregate signed recognized profit/loss by return-group ID.
9. Preserve return-group descriptions in the response while aggregating by IDs.
10. Exclude unlinked legacy Investments.
11. Keep contribution, withdrawal, and valuation source IDs unique before grouping.

Primary touchpoints:

- `app/services/logic/finder/monthly_analysis_json.rb`
- `spec/services/logic/finder/monthly_analysis_json_spec.rb`

Acceptance criteria:

- piggy-bank principal never appears in ordinary income/outcome
- source contributions use source installment month/year
- return withdrawals use return installment month/year and expose paid state
- unpaid source contributions remain projected rather than realized
- partial-payment splits report paid and projected remainder without duplication
- linked positive/negative Investments report profit/loss in their own month
- valuation values are not added to withdrawal values as duplicate movement
- grouped contributions remain distinguishable by return group description/ID
- unlinked legacy Investments remain absent
- every Piggy Bank read remains context-scoped

## Slice 4: Routes and Lazy Tab Boundary

1. Add two collection routes:
   - `GET /balances/monthly_analysis` for the Turbo-frame HTML surface
   - `GET /balances/monthly_analysis.json?month=YYYY-MM` for the data contract
2. Add controller actions that always pass `current_user` and `current_context` to the
   finder.
3. Return a localized `422 Unprocessable Entity` JSON error for invalid month input.
4. Refactor `Views::Balances::Mobile` into `Balance History` and `Monthly Analysis`
   tabs.
5. Keep Balance History selected and rendered immediately.
6. Place a lazy Turbo frame in the inactive analysis panel and assign its `src` only
   when the tab is first activated.
7. Reuse the repository's tab components and lazy-frame behavior where their contract
   fits; do not put chart-fetch responsibility into the tab controller.
8. Preserve the loaded analysis frame when switching back and forth.
9. Add English and Portuguese tab, state, direction, failure, and unassigned copy
   before using the keys.

Primary touchpoints:

- `config/routes.rb`
- `app/controllers/balances_controller.rb`
- `app/views/balances/mobile.rb`
- `app/views/balances/monthly_analysis.rb`
- `config/locales/controllers/static/balances.yml`
- `spec/requests/balances_spec.rb`

Acceptance criteria:

- initial `/balances` starts only the existing balance summary and trend requests
- initial `/balances` does not request analysis HTML or JSON
- first analysis activation loads its frame once
- analysis HTML contains no ApexCharts dependency
- JSON is scoped to the active context
- invalid month input never becomes an unbounded or current-month query
- `/balances/legacy` is unchanged and remains reachable

## Slice 5: Monthly Controls and Visualization

1. Add a focused `balances_monthly_analysis_controller.js` inside the lazy frame.
2. Register the controller through the repository's generated Stimulus manifest.
3. Render previous/next icon buttons and one month control starting at the current
   month.
4. Request only the selected month and retain that selection across retry.
5. Abort the prior fetch or ignore its response when a newer month request exists.
6. Render income, outcome, and ordinary net summaries.
7. Render four Chart.js horizontal-bar panels:
   - income by category bundle
   - outcome by category bundle
   - income by entity bundle
   - outcome by entity bundle
8. Render a textual ranked list for each chart.
9. Render a separate Transfers section with sent, received, and failed groups and
   totals.
10. Render a separate Piggy Banks section with grouped contributions, paid/projected
    withdrawals, and signed recognized profit/loss.
11. Render loading, empty, error, and retry states without collapsing panel dimensions.
12. Destroy old charts before re-render and all charts on disconnect.
13. Use safe DOM construction and `textContent` for payload labels.
14. Pass locale/currency configuration from the server instead of hard-coding it in
    JavaScript.
15. Provide dark-mode chart colors and inspect label wrapping on narrow screens.

Primary touchpoints:

- `app/views/balances/monthly_analysis.rb`
- `app/javascript/controllers/balances_monthly_analysis_controller.js`
- `app/javascript/controllers/index.js`
- `config/locales/controllers/static/balances.yml`

Acceptance criteria:

- analysis JSON is fetched on first frame connection and when the month changes
- stale responses cannot replace the newest month
- all charts display absolute magnitudes and localized currency
- net preserves signed ordinary semantics
- transfer direction remains visible instead of being inferred from color
- Piggy Bank projected withdrawals are visually distinct from realized withdrawals
- a transfer-only or Piggy-Bank-only month is not rendered as empty
- text lists expose the same labels, ordering, and amounts as the charts
- repeated Turbo visits do not leak Chart.js instances

## Slice 6: Regression, Performance, and Manual Verification

1. Expand finder specs across the complete decisions matrix.
2. Add request coverage for HTML, JSON, locale, context, invalid input, and lazy-frame
   hooks.
3. Add a query-count guard or comparable assertion around a high-allocation selected
   month to catch N+1 regressions.
4. Run `node --check` and `yarn build` after Stimulus changes.
5. Run RuboCop after each edit batch.
6. Run the focused balance specs, then `spec/models`, `spec/concerns`, and
   `spec/requests` with the test environment loaded and PostgreSQL access.
7. Start the application only for final UI verification; do not replace the user's
   running server.
8. Verify desktop and mobile viewports in English and Portuguese, light and dark mode.
9. Verify Chart.js canvas pixels are nonblank and charts remain framed after month and
   tab changes.
10. Run full `bin/ci` before merge.

Acceptance criteria:

- existing Balance History summary/trend behavior has no regression
- legacy balances remains the only ApexCharts balances surface
- monthly finder queries remain bounded to one context and month
- every test-matrix reconciliation assertion passes
- mobile controls, long bundle labels, legends, and transfer rows do not overlap
- loading, empty, error, and retry paths are manually exercised

## Detailed Finder Shape

Keep query, normalization, and serialization responsibilities explicit. The initial
finder may use private methods or small value objects; extract collaborators only when
the implementation becomes difficult to test as one class.

Recommended phases:

1. validate month
2. load source installment identities
3. preload parents and ordered allocations
4. classify ordinary versus transfer sources
5. build ordinary bundle accumulators in cents
6. load and aggregate transfer-classified installments
7. load and aggregate failed installments
8. load and aggregate Piggy Bank contribution/withdrawal/valuation sources
9. sort with deterministic tie rules
10. serialize amounts and localized labels

Do not use translated labels as hash keys. Do not use SQL joins that return one source
row per category/entity as the aggregation input. Do not calculate money in floats
before the final payload conversion.

## Suggested Commit Boundaries

1. `feat: define monthly ordinary balance analysis`
2. `feat: separate monthly person transfers`
3. `feat: report monthly piggy bank activity`
4. `feat: add lazy balances analysis tab`
5. `feat: visualize monthly balance analysis`
6. `spec: harden monthly balance reconciliation`
