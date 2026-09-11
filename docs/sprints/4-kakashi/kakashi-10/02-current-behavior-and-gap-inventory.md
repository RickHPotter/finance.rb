# KAKASHI-10 Current Behavior and Gap Inventory

## Inventory Date

This inventory reflects the repository on 2026-09-09, after KAKASHI-06,
KAKASHI-15, KAKASHI-17, and KAKASHI-18 V2.

## Existing Foundations to Preserve

| Area | Current implementation | KAKASHI-10 treatment |
| --- | --- | --- |
| Monthly classification | `Logic::Finder::MonthlyAnalysisJson` and `MonthlyAnalysis::*` | reuse and generalize without changing precedence |
| Ordinary bundles | `MonthlyAnalysis::Ordinary` fixes identity before grouping | preserve exact semantics |
| Transfers | `MonthlyAnalysis::Transfers` separates sent, received, and failed | add links/range capability without reclassification |
| Piggy Banks | `MonthlyAnalysis::PiggyBanks` reports contribution, withdrawal, projection, and valuation | add navigability only |
| Dashboard navigation | KAKASHI-17 `Navigation::*` policies and exact index filters | extend allowlists for validated report state |
| Return navigation | sanitized `return_to` and `Navigation::Dashboard` | allow report state without trusting arbitrary queries |
| Category colors | `CategoryColours::Presentation` | remain the only category chart presentation source |
| Chart library | Chart.js | remain the sole reporting chart library |

## Current Surfaces

### `/balances`

- Balance History loads its existing current-balance and cash-balance JSON endpoints.
- Monthly Analysis lazy-loads a second frame.
- Monthly Analysis accepts exactly one `YYYY-MM` value.
- Ordinary, transfers, failed returns, and Piggy Banks share one month selection.
- Charts have ranked text lists, localized presentation, loading, empty, and error
  states.
- Amounts are not linked to the rows that produced them.

### Category and Entity shows

- Both dashboards show all-context cash/card counts and totals.
- Pie payloads are assembled inside their Phlex show classes.
- Counterpart, bank-account, and user-card breakdowns use another payload shape from
  `/balances` and the account/card interactive charts.
- Existing header actions open exact category/entity-filtered transaction indexes.
- Pie slices and legend rows are display-only.
- There is no selected date range, paid-state filter, direction filter, or trend.

### User bank account and User card shows

- Both dashboards build large interactive category/entity payloads inside Phlex view
  classes.
- Payload construction loads transactions and installments, creates allocation
  groups, calculates totals, fills month points, and serializes Chart.js data.
- The range begins at the earliest eligible installment and is otherwise unbounded.
- Transfer exclusions differ from the complete KAKASHI-06 special-movement
  precedence.
- Chart selections do not produce exact drill-down URLs.
- User-card references are presented, but charge date, billing period, advance, and
  payment contributions are not a shared report contract.

### Budget show

- The dashboard explains the selected budget and exposes exact matched transaction
  links delivered by KAKASHI-17.
- Existing budget model/finder behavior owns matching and remaining-value semantics.
- It does not yet present definition, actual, remaining, and period completion as one
  reconciled report contract.

## Navigation Gaps

`Navigation::Dashboard` currently accepts only a bare owned show path. It deliberately
rejects every query and fragment. That is correct for KAKASHI-17 but cannot restore a
KAKASHI-10 report range after a drill-down.

Cash transaction navigation already allowlists `from_date`, `to_date`, `paid_state`,
category/entity/account IDs, and explicit installment/transaction IDs. Card
transaction navigation has exact category/entity/card/transaction/installment filters
but does not currently share the cash index's date and paid-state parameter contract.

KAKASHI-10 must extend these policies deliberately. It must not pass unchecked report
parameters through generic hashes.

## Data and Architecture Gaps

| Gap | Risk | Required correction |
| --- | --- | --- |
| aggregation inside Phlex views | hard to test, duplicated rules, render-time queries | extract focused report services |
| three incompatible chart payloads | drift in labels, money, colors, and lifecycle | introduce one shared time-series/breakdown shape |
| no explicit source identity in several dashboards | joins can duplicate totals | select canonical installment rows first |
| unbounded account/card history | slow show rendering and oversized HTML | validate range and lazy-load payload |
| display-only chart values | users cannot verify a claim | include exact typed drill-downs |
| combined cash/card totals with separate indexes | one link cannot reconcile both | expose separate cash and card subtotals/actions |
| report state absent from return navigation | returning loses analytical context | canonicalize dashboard query state |
| special exclusions implemented per view | transfers can look like ordinary movement | centralize KAKASHI-06 precedence |
| card dates flattened to installment point | charge/reference/invoice meaning is hidden | retain distinct card metadata |
| client owns grouping/selection assumptions | financial behavior can drift in JavaScript | server owns classification and totals |

## Filter Compatibility Inventory

| Destination | Existing exact identity | Missing for KAKASHI-10 |
| --- | --- | --- |
| Cash index | transaction IDs, installment IDs, category, entity, account | canonical report-source adapter and bounded range state |
| Card index | transaction IDs, installment IDs, category, entity, user card | date range and paid-state parity where destination query supports it |
| Budget index/show | budget IDs and month/year state | report range restoration on source show |
| Category/entity show | owned bare dashboard path | allowlisted report query on dashboard return path |
| Account/card show | owned bare dashboard path | allowlisted report query on dashboard return path |
| Balances | `tab` and one `month` | navigable breakdown state while retaining KAKASHI-06 compatibility |

## Mutation Freeze

The following areas are adjacent to reporting but explicitly frozen:

- actionable-message eligibility, delivery, auto-apply, correction, supersession,
  read state, and revert;
- exchange/return counterpart creation and synchronization;
- card projection generation and repair;
- Piggy Bank source/return/valuation synchronization;
- budget allocation creation, replacement, and rollback;
- installment pay, partial pay, transfer, mirror, and destroy; and
- balance recalculation and `order_id` assignment.

Any failing mutation spec discovered during KAKASHI-10 is handled as a separate bug or
requires explicit approval before this feature changes its behavior.

## Inventory Conclusion

The necessary records, dashboard routes, exact relationship filters, KAKASHI-06
classification, and chart library already exist. The missing feature is a shared,
bounded, source-identifiable reporting layer and the drill-down wiring around it.
No schema migration is expected for KAKASHI-10 V1.

