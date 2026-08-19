# KAKASHI-21 Product and Data Contract

## Objective

Add an explicit financial decision to the existing user-card reference merge:

1. preserve the current behavior by combining the source invoice into the target; or
2. reallocate the persisted installment sequence one billing cycle forward, matching
   the observed Itaú behavior.

Both modes must remain scoped, atomic, projection-safe, fully audited, and eligible for
operation-wide guarded rollback.

## Current Behavior

`Logic::References.merge` currently accepts adjacent source and target references. It
moves every source `CardInstallment` to the target card-payment cash transaction,
recalculates that target invoice, destroys the source invoice and reference, migrates
source-bucket card-bound exchanges, and synchronizes their return projections.

For a transaction with installments 8 and 9 in the two merged months, this deliberately
puts both installments in the target invoice. That behavior remains valid and available;
KAKASHI-21 does not replace it.

## Vocabulary

| Term | Meaning |
| --- | --- |
| Source bucket | The reference selected in `Reference to merge FROM` |
| Target bucket | The adjacent reference selected in `Reference to merge INTO` |
| Combine mode | Move source content into target without moving later content |
| Reallocate mode | Shift every persisted occupied bucket from source onward forward by one month |
| Tail bucket | The new last occupied bucket produced by reallocation |
| Canonical invoice | The generated `CARD PAYMENT` cash transaction for one user card, context, month, and year |

The submitted values should use stable internal identifiers such as
`combine_into_target` and `reallocate_installments`. Labels are localized and must not
be used as service inputs.

## Explicit Choice Contract

The merge form presents both modes with short consequence text. Neither mode is inferred
from the `UserCard`, card issuer, transaction description, or previous selection.

The write boundary requires `merge_mode`. A missing or unknown mode returns a validation
failure and performs no mutation. This is intentionally stricter than silently using the
legacy behavior because the two choices produce materially different future bills.

`Combine into target` supports the existing previous-month and next-month adjacency
directions. `Reallocate installments` is available only when the target is exactly the
month after the source. Backward reallocation is outside V1.

## Mode A: Combine Into Target

This mode preserves the existing contract:

- move source card installments to the target invoice
- retain each installment's number, count, price, starting price, and transaction
- allow a transaction's source and target installments to share the target bucket
- migrate source-bucket monetary card-bound exchanges to target
- resynchronize the canonical target `EXCHANGE RETURN` and remove an empty source
  projection
- update the target reference closing boundary as the current service does
- destroy the emptied source invoice and source reference
- leave later invoice buckets unchanged

KAKASHI-21 may refactor this path behind a common planner/apply boundary, but its
financial result must not change.

## Mode B: Reallocate Installments

### Bucket Mapping

Reallocation moves content, not the identity of the surviving calendar references:

| Before merge | After merge |
| --- | --- |
| content of `2026-08` | `2026-09` |
| content of `2026-09` | `2026-10` |
| content of `2026-10` | `2026-11` |
| content of the last occupied bucket | one newly occupied tail month |

The source reference/invoice becomes empty and is removed. Existing target and future
reference rows continue to anchor their calendar months. A missing tail reference or
invoice is created through the canonical reference/card-payment path.

Only persisted content is shifted. KAKASHI-21 does not synthesize future installments
beyond those already stored.

### Twelve-Installment Acceptance Example

For `CardTransaction #1` with 12 installments from January through December 2026, a
forward merge from August into September produces:

| Installment numbers | Before | After |
| --- | --- | --- |
| 1–7 | January–July 2026 | unchanged |
| 8 | August 2026 | September 2026 |
| 9 | September 2026 | October 2026 |
| 10 | October 2026 | November 2026 |
| 11 | November 2026 | December 2026 |
| 12 | December 2026 | January 2027 |

Installments 8 and 9 therefore remain in distinct invoice references.

### Affected Rows

The shift set contains every persisted, unpaid `CardInstallment` that:

- belongs to the selected `UserCard`
- belongs to `current_context`
- is in the source bucket or a later occupied bucket

This includes one-installment purchases. Their transaction and installment identity do
not change; the single row moves forward once when it is inside the shift set.

For each moved card installment, only billing-routing attributes change:

- `month` and `year`
- `cash_transaction_id`, pointing to the destination canonical invoice

The following remain unchanged:

- `id` and `card_transaction_id`
- `number` and `card_installments_count`
- `price` and `starting_price`
- `date`, preserving the original purchase/installment schedule chronology
- category/entity allocations and parent `CardTransaction` identity

`CardInstallment#date` is not a billing-bucket identifier. A one-installment purchase
made on August 12 remains dated August 12 when its invoice routing moves from September
to October. Likewise, a multi-installment sequence retains its original consecutive
dates; reallocation must not create a false missing month between installments.

When callbacks create or select the destination card-payment invoice, they use the
destination `Reference` explicitly rather than deriving it from the preserved
installment date. The generated invoice and its cash installment still use the
destination reference's billing date.

### Invoice Reconstruction

After reassignment, each affected card-payment invoice is rebuilt from its final
installment membership. Its price, comment, cash installment price, billing date, paid
state, and counters must agree with that membership. Empty intermediate invoices are
removed; exactly one canonical invoice remains for each occupied destination bucket.
Every installment reassignment remains audited, but aggregate invoice and generated
cash-installment totals are synchronized once from each bucket's final membership
instead of being rewritten after every moved row.

The shift is planned and applied from the latest occupied bucket toward the source.
This avoids temporarily combining neighboring buckets and makes unique routing easier
to validate. The implementation must nevertheless run inside one database transaction;
descending order is not a substitute for atomicity.

### References and Gaps

Existing future references are reused. Empty calendar gaps do not stop the shift: every
affected installment moves exactly one calendar month, not merely to the next occupied
bucket. A canonical destination reference is created when a moved row has no reference
for its destination month.

The source reference is destroyed only after every dependent move and synchronization
succeeds. Target/future reference dates remain the billing dates for their own calendar
buckets. The target closing boundary inherits the source boundary according to the
existing merge rule.

## Exchanges and Generated Projections

KAKASHI-11 remains part of the merge invariant. In reallocate mode, matching monetary
card-bound `Exchange` rows in every shifted bucket move forward with the invoice content,
not only those in the source bucket. Their month/year and date use the destination
reference.

All affected `EXCHANGE RETURN` projections are synchronized through the canonical
exchange projection domain logic. The operation must leave:

- no stale projection in an emptied source bucket
- no duplicate projection for an occupied destination bucket
- projection price and installment totals equal to their attached monetary exchanges
- paid projection history unchanged unless the existing safety policy explicitly
  permits and confirms the operation

Non-card-bound and unrelated exchanges are outside the shift set.

## Safety and Isolation

The apply path must lock and revalidate the selected card, references, invoices,
installments, exchanges, and generated projections in a deterministic order.

Reallocation fails before the first mutation when:

- source and target are missing or not forward-adjacent
- either belongs to another context or user card
- an affected installment/invoice is paid or otherwise locked against schedule changes
- a required destination graph cannot be generated canonically
- an exchange/projection graph cannot be synchronized completely
- duplicate or foreign rows make a unique canonical result ambiguous

The service must never shift another card or context, and it must never return success
after applying only part of the range.

## Audit and Rollback Contract

The merge runs inside one `ApplicationRecord.transaction` and one root
`Audit::Operation`. The operation metadata records scalar values for:

- `reference_merge_mode`
- `user_card_id` and `context_id`
- source month/year and target month/year
- earliest and latest affected bucket

Every domain write must produce an audit version in that operation, including bulk
reassignments, tail creation, source destruction, invoice reconstruction, exchanges,
and generated projections. Balance/order fields may continue to use canonical derived
recalculation, but no financial routing or amount mutation may escape version capture.

The rollback preview must understand reallocation as a complete known graph. It may not
classify the operation as unsupported merely because it contains more than the two
reference transitions recognized by the current merge adapter logic.

After an immediate guarded rollback, a canonical snapshot must match the pre-merge
snapshot for every affected financial record and relationship:

- identical record IDs and parent/child membership
- identical installment schedule, prices, counts, and paid states
- identical invoice/reference routing, dates, closing dates, comments, and amounts
- identical exchange ownership and generated projection graph
- canonically recalculated balances and ordering

The immutable merge audit operation and compensating rollback operation remain in
history by design. Operational timestamps may reflect the compensation; the financial
content and identity must be restored.

Any later divergence in an affected row makes the preview conflicted. Rollback then
fails closed rather than restoring a prefix of the shifted range.

## Explicitly Out of Scope

- automatically selecting a mode from the issuer or card name
- changing installment number/count or splitting/combining installment values
- backward installment reallocation
- rewriting paid history to force a reallocation
- changing the schedule of future installments that are not persisted
- repairing reference merges completed before audit capture
- partial or per-record rollback of a merge operation
