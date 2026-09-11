# KAKASHI-10 Decisions and Test Matrix

## Locked Product Decisions

### D1 — Reports explain; existing workflows mutate

KAKASHI-10 adds read-only services, endpoints, controls, charts, lists, and links.
Edits, payment, projection, correction, repair, and rollback continue through their
existing guarded workflows.

### D2 — KAKASHI-06 classification remains authoritative

Range reports reuse ordinary, transfer, failed-return, and Piggy Bank precedence.
No dashboard may maintain its own abbreviated list of special-category exclusions.

### D3 — KAKASHI-17 navigation remains authoritative

Exact relationship filters and sanitized return paths are extended, not replaced.
Report state is accepted only through an explicit allowlist and validated value object.

### D4 — The default is a rolling twelve calendar months

The default range begins on the first day of the month eleven months before the
current month and ends on the current month's last day. This replaces unbounded
all-history chart payloads without making a new user preference.

### D5 — V1 supports day and month granularity

Month is the default. Month ranges are capped at 24 months and day ranges at 93 days.
Weekly grouping is deferred because week boundary/label semantics require a separate
locale decision and are not necessary for the named workflows.

### D6 — Paid state belongs to installments

`paid`, `pending`, and `all` filter canonical source installments. A transaction with
mixed installment states may contribute to both filtered views through different
installments.

### D7 — Combined totals have typed drill-downs

There is no invented combined editable ledger. A mixed cash/card amount exposes cash
and card subtotals and destinations separately, and those subtotals reconcile to the
combined value. Sets above the navigation limit are represented by bounded chunks
whose amounts and counts reconcile to the same typed subtotal.

### D8 — Counts mean unique installments

Report source counts are unique installments unless a label explicitly says
transactions. Allocation joins never increase the count.

### D9 — Money stays in integer cents on the server

Services aggregate integer cents. Serialization and localized helpers convert only at
the presentation boundary.

### D10 — Empty time buckets are explicit

Every day/month inside the selected range appears in a time series even when its value
is zero. This keeps comparisons and chart axes stable.

### D11 — Account balance history is not reconstructed

Account reports explain movement and display existing recorded balance context. They
do not infer missing historical balances or trigger recalculation.

### D12 — Card dates remain distinct

Billing placement follows card installment/reference semantics. Purchase date,
installment date, closing date, due date, advance, invoice, and payment identity remain
separate metadata.

### D13 — Budget period completion is temporal

Period completion measures elapsed time in the configured budget period. Utilization
measures actual consumption against definition. Neither substitutes for the other.

### D14 — Report surfaces stay on owning dashboards

Category, entity, account, card, and budget analysis lives on their show pages.
Transfer/return analysis remains in `/balances`. V1 adds no generic report-builder
screen.

### D15 — Expensive payloads are lazy and stale-safe

Dashboard shells render first. Filter changes issue bounded report requests, and a
late response for old state cannot replace the newest result.

### D16 — Accessible text is part of the financial contract

Every chart point and breakdown exists in a textual summary with the same label,
order, amount, and drill-down. Canvas rendering is optional presentation.

### D17 — Actionable-message behavior is frozen

Send, receive, auto-apply, manual correction, supersession, read state, revert, and
message-derived exchange behavior do not change. Refactoring adjacent read queries is
allowed only with coverage proving those rules remain identical.

## Shared Query-State Matrix

| Scenario | Expected |
| --- | --- |
| omitted state | canonical rolling twelve-month/month/all/all defaults |
| valid ISO boundaries | inclusive range in `Time.zone` |
| invalid date | localized 422 report error; no query broadening |
| `from_date > to_date` | localized 422 report error |
| day range over 93 days | localized 422 report error |
| month range over 24 months | localized 422 report error |
| unknown paid state/direction/granularity/sort | rejected or canonical safe default, never interpolated into SQL |
| refresh with URL state | same controls and data restored |
| return from drill-down | same source dashboard and report state restored |
| external/cross-user return path | rejected by navigation policy |

## Canonical Source and Classification Matrix

| Scenario | Expected |
| --- | --- |
| one installment with two categories | one source row and one deterministic category bundle |
| one installment with two entities | one source row and one deterministic entity bundle |
| allocation join repeated | amount/count unchanged |
| cash/card installment IDs equal | remain distinct typed identities |
| installment outside range | excluded |
| transaction date inside but installment outside | excluded from accounting period |
| generated card-payment cash | excluded from ordinary movement |
| exchange family | transfer/return only |
| failed return | failed-transfer only, existing amount-source rule retained |
| Piggy Bank contribution/return | Piggy Bank only |
| valuation Investment | Piggy Bank valuation only |
| ordinary unassigned row | stable neutral `unassigned` bundle |
| other context has matching IDs/labels | excluded |

## Category and Entity Trend Matrix

| Scenario | Expected |
| --- | --- |
| category with cash income and card outcome | separate direction series and typed subtotals |
| entity with mixed paid/pending installments | each filter includes only matching installments |
| multi-category transaction anchored by one member | included once; counterpart uses full bundle |
| multi-entity transaction anchored by one member | included once; counterpart uses full bundle |
| range contains empty months | zero buckets remain present |
| day granularity | one bucket per inclusive calendar day |
| legend/text/chart comparison | identical ordering and values |
| cash breakdown clicked | exact cash destination only |
| card breakdown clicked | exact card destination only |
| combined amount displayed | cash subtotal + card subtotal = combined amount |
| Category reciprocal pie | current-context Entities across the category's complete history; source filter remains available |
| Entity reciprocal pie | current-context Categories across the entity's complete history with accessible category colours |
| trend filters changed | bounded trend changes; companion reciprocal pie retains its resource-wide allocation scope |

## Bank Account Movement Matrix

| Scenario | Expected |
| --- | --- |
| ordinary income/outcome | separate signed movement and correct net |
| paid/pending mix | subtotals reconcile with all |
| exchange/return on account | separate transfer family |
| Piggy Bank movement | separate Piggy Bank family |
| generated card-payment cash | identified/excluded according to KAKASHI-06 |
| recorded installment balance exists | may be displayed as context, never recalculated |
| many allocations | query count remains bounded |
| another owned account | excluded |

## User Card Movement Matrix

| Scenario | Expected |
| --- | --- |
| standalone purchase | assigned to canonical billing period |
| multi-installment purchase | each installment contributes in its own billing period |
| purchase near closing date | purchase date and reference dates remain distinguishable |
| reference shifted | report follows current canonical reference placement |
| paid/pending mix | installment state determines membership |
| advance | identified separately from ordinary spend |
| generated payment cash counterpart | not counted as a second card expense |
| another owned card | excluded |

## Budget Performance Matrix

| Scenario | Expected |
| --- | --- |
| no matched movement | zero actual, full remaining, valid period completion |
| cash-only match | cash subtotal equals actual |
| card-only match | card subtotal equals actual |
| mixed cash/card match | typed subtotals sum to actual |
| multi-allocation match | source installment counted once |
| inclusive budget | existing inclusive matching retained |
| exclusive budget | existing exclusive matching retained |
| first-installment-only | only canonical first installment included |
| overspent | utilization may exceed 100%; remaining is truthful |
| inactive budget | historical report remains read-only and explainable |

## Transfer, Return, and Piggy Bank Matrix

| Scenario | Expected |
| --- | --- |
| sent EXCHANGE | sent total and exact source link |
| received EXCHANGE RETURN | received total and exact generated/source identity |
| BORROW RETURN | sent return total and exact link |
| failed return | failed section only with existing `starting_price` rule |
| shared exchange pair | current-context side only; no counterpart duplication |
| Piggy Bank contribution | principal contribution link |
| Piggy Bank withdrawal/return | return link and projection metadata |
| Piggy Bank valuation | Investment link, not ordinary cash link |
| pre-existing Monthly Analysis consumer | original keys and totals remain compatible |

## Request, UI, and Performance Matrix

| Scenario | Expected |
| --- | --- |
| guest report request | existing authentication flow |
| same-context resource report | 200 |
| other-context resource ID | 404 |
| initial show render | does not execute full report payload query |
| filter changed rapidly | latest response wins |
| request fails | stable localized error with retry |
| empty result | stable textual empty state; no broken chart |
| keyboard/screen reader | controls labelled and textual data complete |
| narrow viewport | no horizontal overflow or clipped action |
| dark mode | controls, chart, legend, and states remain legible |
| large bounded dataset | no N+1 growth and response stays within agreed query bound |
| report GET | no writes, audit versions, jobs, or timestamp changes |

## Verification Commands

Before RSpec, load `.env.test` when it exists and `.env` otherwise.

```text
bin/rubocop -A
bin/rspec spec/services/logic/finder/monthly_analysis_json_spec.rb
bin/rspec spec/services/reports spec/services/navigation
bin/rspec spec/requests/balances_spec.rb spec/requests/categories_spec.rb spec/requests/entities_spec.rb
bin/rspec spec/requests/user_bank_accounts_spec.rb spec/requests/user_cards_spec.rb spec/requests/budgets_spec.rb
bin/rspec spec/features
bin/ci
```

Exact spec paths may follow the final namespace selected in Slice 1. Full CI is the
closure requirement.

## Open Decisions

There are no blocking product decisions for Slice 1. The defaults above deliberately
favor bounded queries, existing index destinations, and compatibility with
KAKASHI-06/KAKASHI-17. If manual review shows that a rolling twelve-month default is
not the desired daily view, that single default can change without altering the data
or navigation contract.
