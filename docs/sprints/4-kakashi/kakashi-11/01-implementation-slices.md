# KAKASHI-11 Implementation Slices

## Overview

KAKASHI-11 makes user-card reference merges update associated card-bound `Exchange` rows and their generated `EXCHANGE RETURN` projections, preventing stale exchange return buckets that diverge from their invoices.

## Slice 1 — Card-bound Exchange Migration in Reference Merge

**Goal:** Extend `Logic::References.merge` to include the migration and projection synchronization of card-bound exchanges.

### Deliverables

- Wrap the entire `Logic::References.merge` flow inside a single `ApplicationRecord.transaction`.
- Find `Exchange` rows in the source month/year where `bound_type` is `:card_bound` and the source `CardTransaction` belongs to the merged `user_card` and context.
- Update the matching `Exchange` rows: set `month` and `year` to the target reference month/year, and set `date` to the target reference date.
- After updating the exchanges, trigger projection synchronization for both the old source projection bucket and the target projection bucket.
- This ensures the source projection cash transaction is destroyed if it's empty, and the target projection cash transaction is created/updated with the combined total of the merged exchanges.
- Handle any duplicate same-bucket projections safely using the rules defined in `ExchangeCashTransactable`.
- Trigger a balance recalculation from the earliest affected date to ensure the totals reflect the changes.

### Acceptance

- Standard card installment merge still works as expected.
- Source-month card-bound monetary exchanges are migrated to the target month.
- The `EXCHANGE RETURN` projection for the target month absorbs the moved exchanges.
- The source `EXCHANGE RETURN` projection is destroyed if all of its exchanges were moved.
- Balances are recalculated correctly.
- The operation is atomic and rolls back entirely if projection synchronization fails.
