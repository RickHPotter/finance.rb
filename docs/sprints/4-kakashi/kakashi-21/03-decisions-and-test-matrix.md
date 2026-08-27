# KAKASHI-21 Decisions and Test Matrix

## Locked Product and Architecture Decisions

### D1: The merge mode is explicit and required

The form and service require `combine_into_target` or `reallocate_installments`.
Missing/unknown values fail without mutation. No issuer-based default is introduced.

### D2: Combine mode preserves today's result

Source content joins target content and later buckets do not move. KAKASHI-21 may
refactor the code path but must not alter this result.

### D3: Reallocation is a forward-only V1 operation

The target must equal `source.next_month`. Existing backward adjacent merges remain
available only in combine mode.

### D4: Reallocation is bucket-based, not transaction-based

Every persisted unpaid card installment for the selected card/context at or after the
source moves forward one calendar month. This prevents installment collisions and also
moves independent one-installment purchases in later shifted invoices.

### D5: Installment identity and economics do not change

Reallocation changes billing routing only. IDs, transaction parents, installment
numbers/counts, prices, starting prices, and original purchase/schedule dates remain
identical. `month`/`year` and invoice membership move independently from `date`.

### D6: Calendar gaps remain gaps

Each row moves to `original_bucket.next_month`, even when that destination was previously
empty. It does not jump to the next occupied invoice.

### D7: Existing references and invoices are reused canonically

The implementation reuses one valid destination graph per card/context/bucket and
creates only missing graph rows. The final tail may cross a year boundary.

### D8: Apply order is latest-to-earliest inside one transaction

Descending mutation avoids transient bucket coalescing. All locks, writes, projection
synchronization, validation, and source cleanup still belong to one database transaction.

### D9: Paid or unsupported history fails closed

V1 does not rewrite paid/locked installments merely to imitate issuer behavior. Any
unsafe row blocks the reallocation before mutation. Existing guarded confirmation rules
continue to govern rollback of otherwise supported paid history.

### D10: Card-bound exchanges follow their invoice buckets

All matching monetary card-bound exchanges in the shifted range move forward once and
their `EXCHANGE RETURN` projections are resynchronized through canonical domain logic.

### D11: The merge is one audit operation

Both merge modes record all business mutations under one `AuditOperation`. Metadata
identifies the mode and affected range. Recalculation is part of the same transactional
outcome.

### D12: Rollback restores the complete operation or nothing

The known reallocation graph must be supported by KAKASHI-08 adapters. Partial rollback,
force apply, and per-row compensation are not introduced.

### D13: Exact restoration means financial graph equality

After compensation, all affected domain IDs, attributes, routing, membership, and
derived financial values equal the canonical pre-merge snapshot. Immutable audit rows
remain, and operational timestamps may show that compensation occurred.

### D14: Later divergence blocks rollback

If any affected record no longer matches the merge operation's expected after-state,
the rollback preview is conflicted. The user must not receive a partially restored
schedule.

### D15: No schema change is assumed for merge mode

The selection is an operation parameter and audit metadata value, not a persistent
`UserCard` preference. A migration is added only if implementation discovery proves a
separate durable invariant is necessary.

## Core Schedule Matrix

| Scenario | Mode | Expected result |
| --- | --- | --- |
| Source August, target September; installments in both | combine | both installments are in September |
| Source August, target September; installments in both | reallocate | August content → September; September content → October |
| 12 installments January–December; merge Aug → Sep | reallocate | Jan–Jul unchanged; Aug–Dec move to Sep–Jan |
| One-installment purchase in source | reallocate | moves to target once; number/count remain `1` |
| One-installment purchase in target | reallocate | moves to target.next_month once |
| Empty October between occupied Sep and Nov content | reallocate | Sep → Oct and Nov → Dec; the original gap moves with the sequence boundaries |
| December tail | reallocate | destination is January of next year |
| Source after target | combine | existing adjacent combine behavior |
| Source after target | reallocate | rejected, no mutation |
| Missing mode | n/a | `422`, no audit operation, no mutation |
| Unknown mode | n/a | `422`, no audit operation, no mutation |

## Attribute Invariants

For every moved `CardInstallment`:

| Attribute | Expected |
| --- | --- |
| `id` | unchanged |
| `card_transaction_id` | unchanged |
| `number` | unchanged |
| `card_installments_count` | unchanged |
| `price` / `starting_price` | unchanged |
| `month` / `year` | original bucket plus one month |
| `date` | unchanged original purchase/installment schedule date |
| `cash_transaction_id` | destination canonical invoice ID |
| `paid` | remains false; paid rows block V1 reallocation |

The destination invoice's generated billing date still follows its destination
`Reference`; preserving `CardInstallment#date` must not cause callback routing to reuse
the old reference or mark the new invoice paid from the old due date.

For every affected invoice:

| Invariant | Expected |
| --- | --- |
| Membership | exactly the card installments mapped to its bucket |
| Price | sum of final member prices |
| Comment | canonical upfront/installments summary |
| Cash installment | one canonical row with matching amount/date |
| Reference date | matches the bucket's `Reference#reference_date` |
| Empty source | invoice destroyed |
| Occupied destination | exactly one invoice |

## Planner and Service Specs

| Scenario | Expected plan/apply result |
| --- | --- |
| Valid forward adjacent references | applyable plan with deterministic bucket map |
| Non-adjacent references | validation failure, zero writes |
| Foreign context reference/invoice | excluded and request fails safely |
| Foreign user card installment in same month | untouched |
| Existing destination reference and invoice | reused |
| Missing tail reference/invoice | planned and created canonically |
| Multiple transactions in one bucket | all move once; no duplicate invoice |
| Many installments in one bucket | every reassignment is audited; invoice projection updates remain bucket-bounded |
| Same transaction spans source/target | installments remain in separate buckets after reallocation |
| Paid affected installment | blocked before mutation |
| Locked/generated unsupported graph | blocked with explicit reason |
| Failure in middle bucket | database transaction restores every prior bucket |
| Failure during final invoice validation | no source cleanup commits |
| Failure during balance recalculation | entire merge rolls back |

## Exchange Projection Specs

| Scenario | Expected |
| --- | --- |
| Monetary card-bound exchange in source | moves to target/date and projection follows |
| Monetary card-bound exchange in target | moves to following bucket in reallocation mode |
| Exchanges in several future buckets | each moves exactly one month |
| Cash-bound or unrelated exchange | unchanged |
| Same month on another card/context | unchanged |
| Empty source projection after shift | destroyed |
| Existing destination projection | synchronized/merged to one canonical projection |
| Paid projection history | obeys existing safety rule; never silently rewritten |
| Projection synchronization raises | all installment/reference/exchange writes roll back |

## Request and UI Specs

| Scenario | Expected response |
| --- | --- |
| GET merge form | both localized choices and consequences render |
| Turbo GET merge form | same choice contract in HTML response |
| POST combine mode | `303` to preserved user-card destination |
| POST reallocate mode | `303` after complete shift |
| Missing/invalid mode | `422`, form retains dates and shows validation feedback |
| Backward reallocation | `422`, combine remains available |
| Wrong user's card/reference | `404` |
| Derived context | only derived-context graph mutates |
| Preserved `return_to` | success/cancel navigation remains KAKASHI-15 compliant |

## Audit and Rollback Specs

### Audit capture

| Assertion | Expected |
| --- | --- |
| Root operations created by one merge | exactly one committed operation |
| Metadata mode | exact selected stable value |
| Metadata scope/range | selected card/context and source/target/tail buckets |
| Version families | every mutated Reference, CashTransaction, CardInstallment, CashInstallment, Exchange, and companion projection family |
| Created tail | create events included in merge operation |
| Destroyed source | destroy events included in merge operation |
| Bulk movement | each moved business row has an auditable before/after transition |

### Fresh rollback

Run the following sequence once for combine mode and once for reallocation mode:

1. Capture a canonical financial graph snapshot.
2. Apply the selected merge mode.
3. Build `Audit::Rollback::Preview` for the merge operation.
4. Assert `previewable` (or only the documented confirmation requirement).
5. Apply the compensating rollback.
6. Capture the graph again.
7. Assert equality of IDs, domain attributes, associations, invoice membership,
   references, exchanges/projections, balances, and ordering.
8. Assert both immutable operations remain linked in audit history.

### Conflict/failure cases

| Scenario | Expected |
| --- | --- |
| A moved installment edited after merge | preview `conflicted`; no compensation |
| Tail invoice changed after merge | preview `conflicted`; no compensation |
| Exchange/projection changed after merge | preview `conflicted`; no compensation |
| Missing dependency | preview read-only/conflicted with precise issue |
| Compensation validation failure | rollback operation fails; merged state remains complete |
| Integrity verification failure | rollback transaction aborts; no partial restoration |
| Second apply of same valid rollback token | idempotent existing rollback result |

## Concurrency Matrix

| Scenario | Expected |
| --- | --- |
| Two reallocations for same card/context | serialize; second replans or fails stale |
| Combine and reallocate race on same card/context | serialize; no mixed mode result |
| Independent cards in same context | may proceed independently |
| Same card in different contexts | isolated; no cross-context locks/mutations beyond shared parent read |

## Completion Gate

KAKASHI-21 is complete only when:

- combine mode preserves the existing behavior
- reallocate mode passes the 12-installment year-boundary acceptance case
- KAKASHI-11 projection integrity remains true across the full shifted range
- a real reallocation operation can be previewed and fully compensated by AuditRollback
- canonical before/after-rollback graph snapshots match
- focused specs, affected audit/request/service suites, RuboCop, and local CI pass
