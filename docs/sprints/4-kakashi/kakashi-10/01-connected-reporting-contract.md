# KAKASHI-10 Connected Reporting Contract

## Objective

Turn the existing finance dashboards into a connected analysis layer. A user must be
able to see a total or chart, understand the financial rule behind it, and open the
exact cash or card installments that produced it without losing context or report
state.

KAKASHI-10 is a read-only reporting feature. It reorganizes and extends existing
analysis queries; it does not change transaction creation, update, payment,
projection, reference, exchange, Piggy Bank, subscription, budget-allocation, or
actionable-message mutation rules.

## Relationship to Delivered Work

### KAKASHI-06 is the financial classification authority

The Monthly Analysis implementation already defines:

- ordinary income and outcome;
- deterministic category and entity bundles;
- exchange and return precedence;
- failed transfer presentation;
- Piggy Bank principal and valuation treatment;
- installment-month placement; and
- Chart.js loading and lifecycle behavior.

KAKASHI-10 may generalize those queries from one month to a bounded range, but it must
not create a competing classification system. The existing one-month `/balances`
Monthly Analysis remains compatible throughout delivery.

### KAKASHI-17 is the navigation authority

KAKASHI-17 already delivered context-scoped show dashboards and exact relationship
filters for cash transactions, card transactions, budgets, subscriptions, bank
accounts, user cards, categories, entities, investments, references, and generated
records. KAKASHI-10 reuses those routes and filter contracts.

This feature does not repeat the KAKASHI-17 dashboard inventory. It adds report-state
navigation and makes previously display-only chart values reconcilable.

## Report Surfaces

Reports live beside the resource that gives them meaning. V1 does not introduce a
generic report builder or a second finance home page.

| Surface | Report | Scope |
| --- | --- | --- |
| Category show | income/outcome trend and counterpart breakdown | selected category in `current_context` |
| Entity show | income/outcome trend and counterpart breakdown | selected entity in `current_context` |
| User bank account show | cash movement and balance contribution | selected account in `current_context` |
| User card show | card movement, paid state, billing references, advances, and payments | selected card in `current_context` |
| Budget show | definition, matched actual, remaining amount, and period completion | selected budget in `current_context` |
| Balances Monthly Analysis | navigable ordinary, transfer, failed-return, and Piggy Bank summaries | selected month and `current_context` |

The first four surfaces are lazy-loaded when their report section becomes active or
visible. The ordinary resource summary and navigation render without waiting for an
expensive report query.

## Shared Query State

A focused value object owns parsing, validation, canonical serialization, and range
boundaries. Controllers and views must not each reinterpret raw parameters.

V1 report state is:

| Parameter | Values | Default |
| --- | --- | --- |
| `from_date` | ISO date | first day of the month eleven months before `to_date` |
| `to_date` | ISO date | last day of the current month |
| `granularity` | `day` or `month` | `month` |
| `paid_state` | `all`, `paid`, or `pending` | `all` |
| `direction` | `income`, `outcome`, or `all` | `all` |
| `sort` | report-specific allowlisted key | deterministic report default |

Rules:

1. The range is inclusive in `Time.zone`.
2. Month granularity accepts at most 24 calendar months.
3. Day granularity accepts at most 93 calendar days.
4. Invalid, reversed, or oversized ranges return a localized validation response;
   they never silently broaden to all history.
5. Canonical report links include all non-default state required to restore the same
   view.
6. Resource identity is derived from the context-scoped route record, never from an
   unvalidated report parameter.
7. URL state may be carried between meaningful related dashboards, but it must not be
   copied into mutation payloads.

The rolling twelve-month default keeps existing all-history charts bounded while
remaining useful for daily comparison. A resource with less history simply returns
empty buckets where appropriate.

## Canonical Source Row

Every report classifies source rows before joining categories, entities, references,
or other many-to-many relationships. The internal identity is:

```ruby
{
  installment_type: "CashInstallment", # or "CardInstallment"
  installment_id: 123,
  transaction_type: "CashTransaction",
  transaction_id: 456,
  occurred_on: Date.new(2026, 9, 1),
  period_key: "2026-09",
  amount_cents: -12_345,
  paid: false
}
```

The tuple `[ installment_type, installment_id ]` is unique inside a report result.
Allocation joins enrich that row after identity is fixed and must not multiply its
amount.

All aggregation remains integer cents until JSON serialization and localized display.
Displayed totals, textual lists, chart points, and drill-down subtotals use the same
source-row set.

## Allocation Bundle Semantics

Category and entity reports preserve KAKASHI-06 deterministic bundles:

- one installment with several categories contributes its full magnitude once to one
  ordered category bundle;
- one installment with several entities contributes its full magnitude once to one
  ordered entity bundle;
- bundle identity is based on sorted record IDs, not translated labels;
- an empty allocation is represented by a stable `unassigned` key;
- category color presentation comes from `CategoryColours::Presentation`;
- entity and unassigned bundles use neutral presentation; and
- entity allocation prices are not interpreted as proportional shares.

When a report is anchored to one category or entity, membership means the source
transaction contains that allocation. The counterpart dimension still uses the full
deterministic bundle.

## Ordinary and Special Movement Precedence

Classification order stays identical to KAKASHI-06:

1. generated card-payment cash projections are excluded from ordinary movement;
2. failed returns belong to the failed-transfer section;
3. exchange families belong to transfer/return reporting;
4. Piggy Bank sources and returns belong to Piggy Bank reporting; and
5. remaining installments are ordinary income or outcome.

An installment appears in one top-level movement family only. KAKASHI-10 does not
change the send, receive, auto-apply, supersession, correction, or revert eligibility
of any actionable message.

## Date and Paid-State Semantics

### Cash

- Accounting placement uses the cash installment date and stored installment
  month/year semantics already used by KAKASHI-06.
- Paid state comes from the cash installment.
- Account movement is scoped through the owning cash transaction's bank account.
- `balance` is displayed only as recorded balance context; report aggregation never
  reconstructs or rewrites balances.

### Card

- Accounting placement uses the card installment billing period.
- Purchase/charge date remains transaction metadata and is not relabelled as invoice
  date.
- Billing reference and its closing/due dates remain distinct fields.
- Advance and generated card-payment cash rows remain identifiable rather than being
  flattened into ordinary card spend.
- Paid state comes from the card installment.

### Budget

- The budget's configured month/year defines its reporting period.
- Actual consumption uses the existing canonical budget matching logic.
- `starting_value`/definition, actual matched consumption, `remaining_value`, and
  period completion are separate values.
- `first_installment_only` and inclusive allocation semantics remain authoritative.

## Drill-down Contract

A displayed amount is actionable only when the destination can reproduce its source
membership exactly.

Because cash and card transactions have separate indexes, a combined amount exposes
separate labelled drill-downs:

- `Cash — amount (count)` opens the exact cash installments/transactions;
- `Card — amount (count)` opens the exact card installments/transactions.

If only one source type contributes, the amount may link directly to that index. A
combined total must not pretend that one index explains both types.

Drill-down links use existing bounded relationship filters where possible. A finite
calculated set uses explicit installment or transaction IDs, subject to the existing
navigation size limits. Every destination receives a sanitized `return_to` pointing
to the source dashboard with its validated report state.

The following reconciliation must always hold:

```text
reported amount
= cash drill-down subtotal
+ card drill-down subtotal
```

Counts refer to unique source installments unless the label explicitly says
transactions.

## Payload Contract

Report services return presentation-neutral data. A report payload contains:

- canonical query state;
- scope/resource identity;
- signed summary totals in serialized currency units;
- ordered time buckets, including empty buckets inside the selected range;
- ordered breakdown entries with stable keys and optional color metadata;
- unique source counts by type;
- exact cash/card drill-down URLs; and
- explanatory metadata required for card, budget, transfer, or Piggy Bank semantics.

Ruby views render controls and accessible textual summaries. Stimulus owns only fetch
lifecycle, selection, stale-response protection, and Chart.js rendering; it does not
calculate financial totals or classify rows.

## UI and Accessibility Contract

- Charts supplement, never replace, the same ordered textual data.
- Titles name the resource, range, value meaning, and paid-state scope.
- Income and outcome are shown separately; net is not used to hide either side.
- Signed amounts follow the application's localized currency helper.
- Loading, empty, validation, and network-error states occupy stable space.
- Every canvas has an adjacent text summary and an accessible label.
- Legends, tooltips, and lists use identical labels, colors, order, and amounts.
- Filter changes update the URL and ignore or cancel stale requests.
- Light and dark modes use existing dashboard surfaces and calm deterministic colors.
- Mobile controls stack without horizontal overflow and chart height remains bounded.

## Performance Boundary

- Report queries are bounded by validated dates and `current_context`.
- Source installment relations are selected before allocation joins.
- Views receive prepared payloads and do not issue per-entry queries.
- Lazy endpoints must not mutate records, enqueue financial jobs, or create audits.
- The service layer is testable without rendering Chart.js.
- Query-count coverage guards category/entity/account/card reports against N+1 growth.

## Out of Scope

- free-form query language or user-built reports;
- CSV/PDF export;
- forecasting, recommendations, or anomaly detection;
- a unified editable cash-and-card ledger;
- rewriting balances from report output;
- historical snapshots of categories/entities that were later edited;
- arbitrary unbounded all-history chart loads;
- new allocation/proration semantics;
- changes to transaction or actionable-message mutation rules; and
- cosmetic replacement of every existing chart before its data contract is migrated.

