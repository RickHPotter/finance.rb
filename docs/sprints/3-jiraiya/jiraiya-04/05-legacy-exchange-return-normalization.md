# JIRAIYA-04: Legacy EXCHANGE RETURN Projection Sync

## Purpose

This is the first retroactive repair step for old standalone `EXCHANGE RETURN` data.

The goal here is narrow:

- keep legacy `EXCHANGE RETURN.cash_installments` as the source of truth
- rewrite the linked standalone monetary `Exchange` rows to match those installments

This step does **not** consolidate multiple legacy one-installment cash transactions into
one shared return yet.

## Why this step exists

Some old standalone exchange-return records were edited through the mirrored
`CashTransaction` / `CashInstallment` side before the normalized model existed.

In those cases, the installment rows represent the historical user-facing truth.

If the linked `Exchange` rows still carry older dates, month/year values, or prices, then:

- the old data is internally inconsistent
- any later normalization would use the wrong source
- shared paid-state sync/debugging becomes misleading

## Scope

Only standalone exchange-return flows are in scope.

Included:

- `CashTransaction.exchange_return`
- has monetary exchanges
- all monetary exchanges have `bound_type == "standalone"`

Excluded:

- `card_bound` exchange returns
- mixed bound-type exchange sets

## Audit behavior

The audit reports candidates where:

- current standalone monetary exchange rows do not match the existing mirrored cash installments

The audit output includes:

- `current_installments`
- `exchange_rows`
- `desired_exchange_rows`

Where:

- `desired_exchange_rows` are derived directly from `current_installments`

## Apply behavior

The apply step:

- updates existing standalone monetary exchanges to match the installment rows
- creates missing exchanges when needed
- deletes extra exchanges when needed
- updates the owning payer `EntityTransaction` total/count fields

It does **not**:

- rewrite the legacy cash installments
- merge multiple exchange-return cash transactions together
- touch card-bound exchange returns

## Tooling

Read-only audit:

```bash
bin/rails legacy_exchange_return_backfill:audit OUTPUT=tmp/legacy_exchange_return_audit.json
```

Dry run:

```bash
bin/rails legacy_exchange_return_backfill:apply DRY_RUN=true OUTPUT=tmp/legacy_exchange_return_apply.json
```

Apply:

```bash
bin/rails legacy_exchange_return_backfill:apply DRY_RUN=false OUTPUT=tmp/legacy_exchange_return_apply.json
```

Apply specific ids only:

```bash
bin/rails legacy_exchange_return_backfill:apply IDS=1806,4428 DRY_RUN=false OUTPUT=tmp/legacy_exchange_return_apply.json
```

## Next step

After this projection-sync step, a second migration can safely consolidate old
families of one-installment standalone exchange-return cash transactions into the
normalized shape:

- one shared `EXCHANGE RETURN` cash transaction
- many mirrored `CashInstallment`
