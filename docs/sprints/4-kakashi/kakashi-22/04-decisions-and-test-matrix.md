# KAKASHI-22 Decisions and Test Matrix

## Locked Product and Architecture Decisions

### D1: Sparse observed values are authoritative

The app records values only when the bank or a final settlement provides an observation.
It does not require daily records and does not synthesize missing history.

### D2: Reconciliation accepts a balance, not a delta

The primary form asks for the current net redeemable value. The service calculates the
signed Investment delta. Manual linked Investment entry remains an advanced workflow.

### D3: Current unpaid projection is the comparison baseline

The observed value describes money still invested. After partial withdrawal, the delta
is calculated against unpaid installments; paid installments are immutable history.

### D4: IOF is not calculated

KAKASHI-22 stores no rate table and calculates no declining tax schedule. Gross yield,
tax, and fees are not separately inferred from one net observation.

### D5: Existing Investment remains the financial delta

The first implementation does not add a valuation-snapshot table. Observation inputs
are captured in immutable audit-operation metadata, while the linked Investment remains
the domain record consumed by projections and reports.

### D6: Zero difference is a successful no-op

No zero-valued Investment is created. The request reports that the values already match
and produces no empty audit operation.

### D7: Paid history is never rewritten

Positive or negative deltas may change only the unpaid remainder. Fully settled groups
cannot be reconciled in the first implementation.

### D8: Availability belongs to the contribution link

The proposed nullable `PiggyBank#iof_exempt_on` is distinct from `return_date`, does not
move projections, and is shown separately for every contribution.

### D9: Group reconciliation is not lot allocation

Several maturity lots may share one return. The bank's observed group total adjusts the
group projection; profit and withheld charges are not apportioned to individual lots.

### D10: Legacy baselines are preserved

No existing `return_price` is recomputed from source price. Reconciliation starts from
the graph as persisted, and any future normalization is a separate audited feature.

### D11: Preview and apply are distinct boundaries

Preview is read-only and returns a deterministic digest. Apply locks, recalculates, and
rejects stale or raced input before mutation.

### D12: One apply is one auditable operation

Investment creation and Piggy Bank projection synchronization commit or roll back
together. The existing guarded rollback must restore the exact pre-apply graph.

### D13: Existing neighboring domains are invariant

KAKASHI-22 does not change ordinary Investment behavior, Monthly Analysis arithmetic,
exchange projections, or actionable-message send/receive/auto-apply rules.

## Approval Gates

### P1: What value can the bank expose before withdrawal?

Confirm one:

- the current net redeemable total is visible before withdrawal; or
- only gross balance plus an IOF/charge amount is visible; or
- only the final settled amount is known.

The drafted V1 form assumes the first. If only gross and charges exist, the form contract
must explicitly accept both rather than asking the user to calculate net value. If only
final settlement exists, atomic reconcile-and-settle becomes part of V1.

### P2: How is `iof_exempt_on` initialized?

Choose one:

- user enters the date manually, with no inferred tax rule; or
- the app proposes contribution date plus 30 calendar days and lets the user edit it.

The second is more convenient but must be confirmed as correct for the actual bank
product. Neither choice calculates IOF money.

## Calculation Matrix

| Scenario | Recorded unpaid | Observed net | Expected result |
| --- | ---: | ---: | --- |
| Pre-maturity value equals principal | 1,000.00 | 1,000.00 | successful no-op; no Investment |
| Day-30 catch-up | 1,000.00 | 1,007.42 | linked Investment `+7.42` |
| Early redemption with small net gain | 1,000.00 | 1,000.35 | linked Investment `+0.35` |
| Previous gross value corrected downward | 1,007.42 | 1,001.10 | linked Investment `-6.32` |
| Previous loss recovers | 995.00 | 1,002.00 | linked Investment `+7.00` |
| Partial withdrawal: lifetime 1,007; paid 200 | 807.00 | 810.50 | linked Investment `+3.50`; paid 200 unchanged |
| Malformed/blank observed value | n/a | invalid | rejected without writes |
| Zero or negative observed balance | n/a | <= 0 | rejected without writes |
| Fully settled group | 0.00 | any | rejected; no reopening in V1 |

## Service and Concurrency Matrix

| Scenario | Expected result |
| --- | --- |
| Valid owned open group | preview includes exact inputs, outputs, and digest |
| Foreign user or context | not found/rejected without information leak |
| Non-Piggy-Bank transaction ID | rejected without writes |
| Broken return/installment arithmetic | rejected with health-check direction |
| Missing Piggy Bank Investment type | actionable configuration failure |
| Valid positive delta | one linked Investment and synchronized return |
| Valid negative delta | one negative linked Investment and synchronized return |
| Zero delta | no Investment, no projection change, no empty audit operation |
| Graph changes after preview | stale result; zero writes |
| Two applies use same preview | at most one commits; second is stale/idempotent |
| Two previews, sequential distinct observations | each later apply recalculates from committed state |
| Projection save raises | Investment, projection, installments, and audit versions all roll back |
| Unrelated Piggy Bank group changes concurrently | independent group remains isolated |

## Paid-History Matrix

| Scenario | Expected result |
| --- | --- |
| No paid return installments | entire unpaid projection becomes observed total |
| Some return already paid | paid rows unchanged; one unpaid remainder becomes observed total |
| Several historical paid splits | all paid IDs/dates/prices unchanged |
| Delta would make lifetime total equal paid total | rejected by V1; use settlement workflow |
| Delta would make lifetime total below paid total | rejected |
| Final installment already paid | reconciliation unavailable |

## Availability Matrix

| Scenario | Expected result |
| --- | --- |
| Two contributions on different dates share a return | each retains its own availability date/status |
| Availability date changes | no return transaction/installment date or amount changes |
| Return date changes | availability date remains unchanged |
| Availability date is blank | shown as not recorded; valuation still works |
| Date is in future | waiting status |
| Date is today or past | available status without implying withdrawal |
| Existing link during migration | remains valid with nullable date |

## Request and UI Matrix

| Scenario | Expected response |
| --- | --- |
| Open generated return detail | reconciliation action and current remaining total visible |
| Source cash transaction detail | navigation to authoritative return remains unchanged |
| GET reconciliation form | localized snapshot language; current totals shown |
| POST preview | no database writes; calculated delta rendered |
| POST apply with valid digest | `303` to return detail with success notice |
| HTML/Turbo validation failure | `422`, submitted values retained, detailed notices stacked |
| Zero-delta apply | `303`/success response explaining no change |
| Double submit | no duplicate adjustment |
| Mobile/dark mode | inputs, monetary comparison, and actions remain usable |
| English/Portuguese | balance, net, adjustment, IOF availability, and status copy localized |

## Audit and Rollback Matrix

| Assertion | Expected |
| --- | --- |
| Committed root operations | exactly one for nonzero apply |
| Metadata | operation kind, scope IDs, observation date, recorded/observed/delta cents, digest |
| Version families | Investment plus every generated return/installment mutation |
| Mutation source | Investment is root/web; projection changes are `piggy_bank_sync` |
| Fresh preview | rollback is previewable under existing guards |
| Applied rollback | exact pre-reconciliation financial graph restored |
| Later valuation edit | rollback preview conflicted |
| Rollback integrity failure | compensation aborts atomically |

## Reporting Regression Matrix

| Scenario | Expected |
| --- | --- |
| Catch-up valuation | full delta recognized in observation month |
| Negative correction | signed loss recognized in observation month |
| Zero reconciliation | no report row or total change |
| Partial withdrawal then reconciliation | withdrawal remains separate; new delta counted once |
| Ordinary Investment | aggregation and generated cash projection unchanged |
| Exchange/actionable message | no policy or projection behavior change |

## Completion Gate

KAKASHI-22 is complete only when:

- both approval gates are resolved in this document;
- the observed-value calculation is correct before and after partial withdrawals;
- preview is write-free and apply is stale-safe, locked, atomic, and retry-safe;
- positive, negative, and zero results follow the contract;
- contribution availability is independent from return scheduling;
- a real reconciliation operation is fully rollbackable;
- reporting and neighboring-domain regressions remain green;
- focused suites, RuboCop, and `bin/ci` pass;
- a manual verification guide and closure report record the final behavior.
