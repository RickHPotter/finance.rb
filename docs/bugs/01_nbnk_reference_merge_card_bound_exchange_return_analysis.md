# NBNK reference merge did not merge card-bound EXCHANGE RETURN projections

## Observation

After merging NBNK reference month `07/2026` into `08/2026`, the ordinary card reference state looks merged, but the card-bound `EXCHANGE RETURN` projection rows did not merge.

Local records checked:

- `/cash_transactions/4264/edit`
  - Description: `[ 07/2026 ] LALA - NBNK`
  - Category: `EXCHANGE RETURN`
  - `cash_transaction_type`: projection from `Exchange`
  - Month/year: `7/2026`
  - Date: `2026-07-08 23:59:59`
  - One unpaid cash installment: `160207`
  - Contains many `Exchange` rows with `bound_type: "card_bound"`, all still on `month: 7, year: 2026`

- `/cash_transactions/4265/edit`
  - Description: `[ 08/2026 ] LALA - NBNK`
  - Category: `EXCHANGE RETURN`
  - `cash_transaction_type`: projection from `Exchange`
  - Month/year: `8/2026`
  - Date: `2026-08-08 23:59:59`
  - One unpaid cash installment: `78179`
  - Contains `Exchange` rows with `bound_type: "card_bound"`, all on `month: 8, year: 2026`

NBNK reference state after the merge:

- `UserCard#3` (`NBNK`) has only the `08/2026` reference among months `7` and `8`.
- The unpaid NBNK card-payment invoice is only the August one:
  - `CashTransaction#4232`
  - `CARD PAYMENT [ NBNK - AUG <26> ]`
  - `month: 8, year: 2026`

So the reference/card-payment invoice merge happened, but card-bound exchange-return projection `#4264` remained in the old July bucket instead of being merged into `#4265`.

## Why It Happened

The merge path is `ReferencesController#perform_merge`, which calls:

```ruby
Logic::References.merge(@user_card, source_reference_date, target_reference_date, context: current_context)
```

Current `Logic::References.merge` does only this:

1. Resolve adjacent source/target dates.
2. Find unpaid card-payment invoice cash transactions for source and target months:
   - `user_card.unpaid_invoices(context:)`
3. Move source invoice `CardInstallment` rows to the target invoice month/year:
   - `source_card_payment.card_installments.update(target_card_payment.slice(:year, :month))`
4. Move target reference closing date.
5. Destroy source reference.

It does not inspect or update `Exchange` rows.

Card-bound `EXCHANGE RETURN` rows are not normal card-payment invoices. They are projection cash transactions produced by `Exchange` rows through `ExchangeCashTransactable`.

For card-bound projections, the grouping key is the exchange bucket:

```ruby
exchange.month
exchange.year
exchange.bound_type == "card_bound"
```

The projection code then groups matching exchanges into an `EXCHANGE RETURN` cash transaction via methods such as:

- `ExchangeCashTransactable#sync_projection_cash_transaction!`
- `#projection_exchanges`
- `#same_projection_bucket?`
- `#same_projection_group?`
- `#card_bound_projection_bucket_month_year`

Because `Logic::References.merge` never changes the source `Exchange` rows from `7/2026` to `8/2026`, the July projection stays valid from the projection layer’s point of view. No projection rebuild is triggered for `#4264` and `#4265`.

## Message replay note

For `notification:update`, comparing `message.reference_transactable.price` directly to `message.replay_payload["price"]` can be misleading in shared exchange flows.

Use this instead when checking what the message would apply locally:

```ruby
local = message.local_reference_for(context: current_context)
payload = message.replay_payload.with_indifferent_access
```

Then compare `local` to `payload`.

Reason: in loan/reimbursement chains, `message.reference_transactable` may be the source transaction or another chain node, while the replay payload is shaped for the receiver-side local transaction that `local_reference_for` resolves.

Also, payload price semantics differ by intent:

- `intent: "loan"` builds an `EXCHANGE` card/cash request from sender-side installments/exchanges.
- `intent: "reimbursement"` builds a receiver-side `BORROW RETURN`.
- Card-bound exchange notifications use the affected exchange rows and may not be semantically equal to the current aggregate projection transaction total if the local comparison target is wrong.

## Recommended Fix

Extend `Logic::References.merge` so reference merges also migrate card-bound exchange projections for the same user card/context.

When merging source month/year into target month/year:

1. Continue doing the current card-payment invoice merge.
2. Find source-month card-bound `Exchange` rows whose source `CardTransaction` belongs to the merged `user_card` and context.
3. Update those exchange rows to target `month/year` and target reference date.
4. Rebuild/sync affected projection cash transactions so:
   - Source projection `EXCHANGE RETURN` is destroyed if empty.
   - Target projection absorbs the moved exchanges.
   - Target projection price, date, installment, and description are recalculated.
   - Balances are recalculated from the earliest affected projection date/month.

The important selection shape is:

```ruby
Exchange
  .joins(entity_transaction: :transactable)
  .where(bound_type: :card_bound, month: source_month, year: source_year)
  .where(entity_transactions: { transactable_type: "CardTransaction" })
  .where(card_transactions: { user_card_id: user_card.id, context_id: context.id })
```

Implementation should avoid raw `update_all` unless a follow-up projection sync is explicit. Updating each exchange through `update!` is safer because `ExchangeCashTransactable` owns projection cleanup/rebuild behavior.

## Suggested Regression Spec

Add coverage to `spec/requests/references_spec.rb` or a service spec for `Logic::References.merge`:

1. Create NBNK-like `UserCard`.
2. Create source and target references, e.g. `07/2026` and `08/2026`.
3. Create source and target unpaid card invoices.
4. Create two card transactions with `EXCHANGE` category and card-bound monetary exchanges:
   - one exchange in source month
   - one exchange in target month
5. Assert two card-bound `EXCHANGE RETURN` cash transactions exist before merge.
6. Perform the reference merge.
7. Assert:
   - source reference is gone
   - only target invoice remains
   - source card-bound exchange row now has target month/year/date
   - source `EXCHANGE RETURN` projection is gone or has no exchanges
   - target `EXCHANGE RETURN` projection includes both exchange rows
   - target projection installment price equals the sum of both exchanges

## Manual Data Repair Shape

For the current NBNK case, the repair should conceptually:

1. Move all `#4264.exchanges.card_bound` from `7/2026` to `8/2026`.
2. Use the August NBNK reference date (`2026-08-08 23:59:59`) for their dates.
3. Trigger projection rebuild so `#4265` absorbs those rows and `#4264` is removed.
4. Recalculate balances from July 2026.

Do not manually change only `cash_transactions.month/year` on `#4264`; that would leave the owning `Exchange` rows inconsistent and the projection layer could rebuild the old state later.

## Implemented Retrofit

The first implemented step was diagnostic visibility in `Logic::ExchangeReturnAudit`.

The audit now flags card-bound `EXCHANGE RETURN` projections when attached monetary `Exchange` rows no longer match the current source `CardInstallment` bill bucket or amount. This catches the stale source projection case, for example a July projection whose exchange rows still have `month: 7, year: 2026` while the corresponding source card installments now belong to August.

The audit also surfaces the target projection when it should absorb stale rows. In the NBNK case, this means both sides are visible:

1. `#4264` as the stale source projection.
2. `#4265` as the August target projection that should absorb the moved rows.

The second implemented step was an explicit repair path on `cash_transactions#show`.

For card-bound `EXCHANGE RETURN` cash transactions, the show page now renders a dedicated “Card-bound projection exchanges” section. It displays:

1. The transaction price.
2. The sum of attached card-bound monetary exchanges.
3. The difference between them.
4. The attached exchange rows, including bucket, date, entity, source card transaction, and price.

The show page displays a “Fix projection” button when any of these conditions are true:

1. The transaction price differs from the sum of attached card-bound monetary exchanges.
2. Any attached card-bound exchange row has a stale bill bucket compared to its source card installment.
3. Any incoming stale card-bound exchange row should move into this projection’s current bucket.
4. Another same-bucket card-bound `EXCHANGE RETURN` projection exists and should be merged.

The repair endpoint is:

```ruby
PATCH /cash_transactions/:id/fix_exchange_projection
```

The repair flow does the following:

1. Moves stale card-bound exchange rows to the current bucket of their source card installment.
2. Uses the matching user-card reference date when available; otherwise falls back to the card due date for that month.
3. Resyncs the projection cash transaction from the attached exchange rows.
4. Detects duplicate same-bucket card-bound `EXCHANGE RETURN` projections.
5. Moves duplicate projection exchange rows into the preferred target projection.
6. Destroys the duplicate projection cash transaction.
7. Resyncs the surviving projection total, date, month/year, description, installment, and paid state.
8. Recalculates balances from the earliest affected date.

For the local NBNK data after the first repair pass, both `#4264` and `#4265` had become internally consistent August projections. The remaining bug was that two standing projections existed for the same bucket. The final fix handles that duplicate state: when `#4264` and `#4265` describe the same August card-bound projection, the existing canonical target projection survives, absorbs the exchange rows, and the duplicate projection is removed.

Current expected manual outcome for the NBNK data:

1. Open `#4264` or the stale/duplicate projection shown by the audit.
2. Click “Fix projection”.
3. The app redirects to the surviving August projection, expected to be `#4265`.
4. Only one August `EXCHANGE RETURN` projection remains.
5. The surviving projection price equals the combined total of both previous projections.

This is a retrofit repair for already-broken historical data. The preventive fix still belongs in `Logic::References.merge`: when a user-card reference is merged, card-bound exchange rows for the source reference should be migrated to the target reference immediately and projection sync should run as part of that merge.

## Implemented Regression Coverage

The current retrofit is covered in `spec/requests/cash_transactions_spec.rb`.

The relevant specs cover:

1. Rendering card-bound projection exchange rows on `cash_transactions#show`.
2. Showing the fix button when transaction total and attached exchange total differ.
3. Resyncing projection price and installment total from attached card-bound exchange rows.
4. Showing the fix button when card-bound exchange buckets are stale even though totals already match.
5. Moving stale exchange rows to the correct bucket.
6. Merging duplicate same-bucket card-bound `EXCHANGE RETURN` projections so only one projection remains.
