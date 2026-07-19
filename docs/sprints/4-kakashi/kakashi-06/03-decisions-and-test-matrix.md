# KAKASHI-06 Balances Monthly Analysis: Decisions and Test Matrix

## Resolved Product Decisions

### D1. Is this a report or a one-month operational view?

Decision: one selected calendar month. Previous/next controls and a month picker change
the selected month. Multi-month comparison, trends, and export are outside V1.

### D2. What date places ordinary movement in a month?

Decision: each cash/card installment's own `month` and `year`. Parent transaction month
does not override installment attribution.

### D3. How are several categories or entities handled?

Decision: build one deterministic bundle per dimension and assign the full installment
amount once. Do not split the amount and do not count it once per allocation.

### D4. What does an empty allocation mean?

Decision: use one localized `Unassigned` bundle. Empty allocations do not disappear
from reconciliation totals.

### D5. What belongs to ordinary income/outcome?

Decision: selected-month cash/card installments after excluding generated card-payment
cash rows, transfer families, failed returns, and Piggy Bank source/return rows. Budgets
are not source rows and remain excluded. `Investment` aggregate CashTransactions are
also excluded so unlinked legacy Investments cannot enter indirectly.

### D6. How are person-to-person transfers valued and dated?

Decision: use each eligible cash/card installment's price and own month/year. The
source and generated return are independent sides: a June `EXCHANGE` source is Sent
in June, while its July `EXCHANGE RETURN` installment is Received in July.

### D7. How is transfer direction determined?

Decision: classify `EXCHANGE` and `BORROW RETURN` as `sent`, and `EXCHANGE RETURN` as
`received`. `EntityTransaction#is_payer` does not determine dashboard direction.
Amounts are displayed as positive magnitudes with explicit direction, and
sent/received totals are not netted.

### D8. How are failed lend/borrow returns represented?

Decision: use the failed cash installment's `starting_price`, group it separately with
a `failed` state, and exclude it from ordinary and sent/received totals.

### D9. Are Piggy Bank principal movements income or spending?

Decision: no. `PIGGY BANK` contributions and generated `PIGGY BANK RETURN` withdrawals
belong to a separate Piggy Banks section.

### D10. How is Piggy Bank activity dated?

Decision:

- contribution: source cash installment month/year
- withdrawal: return cash installment month/year
- recognized profit/loss: linked Investment month/year

Paid source/return installments are realized contributions/withdrawals; unpaid
installments are projected contributions/withdrawals. A partial-payment split may
therefore contribute to different months and states without losing its shared
return-group identity.

### D11. Which Investments are included?

Decision: only Investments explicitly linked through
`piggy_bank_return_cash_transaction_id`. Positive values are recognized profit and
negative values are recognized loss. Unlinked legacy Investments remain excluded.

### D12. Is profit inferred from return minus principal?

Decision: no. Use the explicit signed linked Investment rows. The return projection
already contains principal plus valuation changes, so inferred profit would duplicate
or mistime recognized values.

### D13. How are Piggy Bank groups distinguished?

Decision: aggregate by return CashTransaction ID and display the return-group
description. IDs remain authoritative when descriptions are equal or later change.

### D14. How lazy is the new tab?

Decision: Balance History is rendered immediately. Monthly Analysis uses a lazy Turbo
frame; neither its analysis markup nor its JSON is requested until first activation.
Once loaded, switching tabs preserves the frame and chart state.

### D15. Are category and entity views toggled?

Decision: no. Four ordinary breakdowns remain available together, with responsive
stacking. Each chart has a textual ranked list. Transfers and Piggy Banks are separate
panels rather than chart modes.

### D16. Which chart library is allowed?

Decision: Chart.js is the only chart library on `/balances`. The superseded legacy
route, controller, view, JSON finder, and ApexCharts dependency are removed.

### D17. What is the money precision contract?

Decision: aggregate integer cents in Ruby and convert once at serialization. JavaScript
formats the serialized values using locale/currency configuration supplied by the
server.

### D18. What happens with invalid month input?

Decision: the JSON route returns a localized `422` response. It must not fall back to
the current month or execute an unbounded query.

### D19. What happens if a historical row mixes special families?

Decision: one deterministic precedence prevents duplicate analysis:

1. generated card payment excluded
2. failed return
3. person transfer
4. Piggy Bank
5. ordinary

The underlying category validation/audit remains responsible for reporting the invalid
combination.

## Ordinary Finder Test Matrix

| Scenario | Expected result |
| --- | --- |
| positive cash installment in selected month | included once in income category and entity bundles |
| negative card installment in selected month | included once in outcome category and entity bundles |
| parent transaction month differs from installment month | installment month wins |
| same parent has installments in two months | only selected-month installment included |
| transaction has two categories | one ordered `Category A + Category B` bundle with full amount |
| transaction has two entities | one ordered `Entity A + Entity B` bundle with full amount |
| category/entity association rows load through joins | source installment still counted once |
| no categories | localized category `Unassigned` bundle |
| no entities | localized entity `Unassigned` bundle |
| same translated labels have different ID signatures | bundles remain independently keyed |
| equal amounts in different bundles | stable label/key tiebreak ordering |
| generated card-payment cash row | excluded |
| aggregate Investment CashTransaction | excluded |
| budget in selected month | excluded |
| transfer-family parent | excluded from ordinary data |
| Piggy Bank source or generated return | excluded from ordinary data |
| record belongs to another context | excluded |
| no ordinary rows | zero totals and empty bundle arrays |
| fractional major-unit conversion | exact cent aggregation before serialization |

Reconciliation assertions:

- income category total equals income entity total
- outcome category total equals outcome entity total
- each equals the corresponding included ordinary installment total
- ordinary net equals signed income minus absolute outcome

## Transfer Test Matrix

| Scenario | Expected result |
| --- | --- |
| selected-month EXCHANGE cash/card installment | included once as Sent using installment price |
| selected-month EXCHANGE RETURN cash installment | included once as Received, not ordinary income |
| selected-month BORROW RETURN cash installment | included once as Sent, not ordinary income |
| exchange schedule month differs from source installment month | source installment month wins for Sent |
| source and return installments belong to different months | each side appears only in its own month |
| payer flag conflicts with category direction | category direction wins |
| same entity has several sent installments | one entity/direction aggregate |
| same entity has sent and received installments | two direction aggregates |
| category join could repeat one installment | installment counted once |
| eligible installment set is empty | empty transfer result |
| eligible parent belongs to another context | excluded |
| failed return has current price zero | `starting_price` reported in failed section |
| failed return has several entities | deterministic entity bundle |
| failed return selected | excluded from ordinary and sent/received totals |

Reconciliation assertions:

- total sent equals the sum of serialized `sent` items
- total received equals the sum of serialized `received` items
- failed total is independently derived and never included in those two totals

## Piggy Bank Test Matrix

| Scenario | Expected result |
| --- | --- |
| source contribution in selected month | positive contribution magnitude under its return group |
| source contribution is unpaid | projected contribution rather than realized contribution |
| grouped sources contribute in same month | summed once under shared return ID |
| grouped sources contribute in different months | only selected-month source installments included |
| generated return installment is unpaid | projected withdrawal, not realized withdrawal |
| generated return installment is paid | realized withdrawal |
| partial payment creates paid and unpaid installments | each installment attributed by its own month/state without duplication |
| linked positive Investment in selected month | recognized profit under target return group |
| linked negative Investment in selected month | recognized loss under target return group |
| linked Investment revises future return | valuation shown once; projected withdrawal remains a separate view |
| Investment is not linked to a Piggy Bank Return | excluded |
| Piggy Bank group belongs to another context | contribution, withdrawal, and valuation excluded |
| two groups have the same description | separate return IDs remain separate groups |
| return description changes | stable ID keeps attribution authoritative |
| month contains only Piggy Bank activity | analysis is not empty |

Reconciliation assertions:

- realized/projected contribution totals equal selected-month source installments by
  paid state
- total realized withdrawal equals selected-month paid return installments
- total projected withdrawal equals selected-month unpaid return installments
- recognized profit/loss equals selected-month linked Investment prices
- withdrawal and profit/loss totals are never summed as if they were independent cash
  movements

## Request and Routing Test Matrix

| Scenario | Expected result |
| --- | --- |
| `GET /balances` | Balance History selected with summary, trend, and extremes |
| initial `/balances` response | lazy analysis frame has no active `src` |
| first Monthly Analysis activation | frame HTML requested once |
| reopen already loaded analysis tab | no duplicate frame request |
| valid `month=YYYY-MM` JSON request | selected-month payload and `200` |
| missing or malformed month | localized error and `422` |
| switch active context | JSON contains only that context |
| Portuguese user | Portuguese labels and locale formatting configuration |
| English user | English labels and locale formatting configuration |

## Frontend and Manual Test Matrix

| Scenario | Expected result |
| --- | --- |
| initial page connection | no analysis JSON request |
| analysis frame connects | current month requested |
| previous/next rapidly clicked | only newest response renders |
| month picker changed | charts, lists, transfers, and Piggy Banks update together |
| JSON request fails | selected month retained; error and retry visible |
| retry succeeds | error clears and current selected month renders |
| empty month | explicit empty state and stable layout |
| transfer-only month | Transfers visible; not empty |
| Piggy-Bank-only month | Piggy Banks visible; not empty |
| long category/entity/group label | wraps or truncates with accessible full text; no overlap |
| malicious-looking label text | rendered as text, never interpreted as HTML |
| tab switched repeatedly | no duplicate controllers or leaked charts |
| Turbo navigation away | all Chart.js instances destroyed |
| narrow mobile viewport | controls fit and panels stack coherently |
| desktop viewport | analysis uses balanced two-column breakdown layout |
| dark mode | axes, grids, bars, lists, and states retain contrast |
| canvas inspection | every non-empty chart has nonblank rendered pixels |

## Performance Boundary

The selected month is intentionally bounded, but allocation-heavy users can still
trigger N+1 behavior. Tests or instrumentation should verify that query count does not
grow linearly with installment, category, entity, exchange, PiggyBank-link, or linked
Investment row count.

Do not cache cross-context payloads. Any later cache key must include at least context,
month, locale, and a financial-data version or invalidation boundary.

## Remaining Product Decisions

There are no blocking product decisions for V1. Later iterations may add drill-down,
month comparison, export, or deeper Piggy Bank profitability ratios, but those features
must build on the separate ordinary/transfer/savings contracts rather than recombining
their totals.
