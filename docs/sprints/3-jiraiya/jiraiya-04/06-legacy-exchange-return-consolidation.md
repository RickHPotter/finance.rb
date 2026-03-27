# JIRAIYA-04: Legacy EXCHANGE RETURN Consolidation

## Purpose

This is the second retroactive repair step for old standalone `EXCHANGE RETURN` data.

Step 1 repaired projection drift:

- `EXCHANGE RETURN.cash_installments` stayed as source of truth
- linked standalone `Exchange` rows were rewritten to match

Step 2 consolidates old families that still exist as multiple one-installment
`EXCHANGE RETURN` cash transactions.

## Target shape

After consolidation, one logical standalone exchange-return family should become:

- one `EXCHANGE RETURN` `CashTransaction`
- many `CashInstallment`
- many standalone monetary `Exchange`

All monetary exchanges in that family should point to the same cash transaction.

## Family grouping

The current consolidation audit groups legacy rows by:

- `user_id`
- `context_id`
- payer `EntityTransaction`

Only groups with more than one standalone `EXCHANGE RETURN` cash transaction are
considered candidates.

## Audit behavior

The audit reports:

- the chosen survivor transaction id
- all exchange-return transaction ids in the family
- the payer `EntityTransaction` id
- the desired merged installments
- the current transactions in the family

## Apply behavior

The apply step:

- keeps the lowest-id transaction as the survivor
- moves all standalone monetary exchanges in the family onto that survivor
- renumbers/rebuilds the survivor installments in chronological order
- deletes the legacy sibling exchange-return cash transactions

## Status

Implemented and exercised after projection sync.

This step assumes `05-legacy-exchange-return-normalization.md` has already run,
so the linked standalone `Exchange` rows have already been repaired from the legacy
mirrored installment truth before the family is merged.

## Tooling

Read-only audit:

```bash
bin/rails legacy_exchange_return_backfill:consolidation_audit OUTPUT=tmp/legacy_exchange_return_consolidation_audit.json
```

Dry run:

```bash
bin/rails legacy_exchange_return_backfill:consolidation_apply DRY_RUN=true OUTPUT=tmp/legacy_exchange_return_consolidation_apply.json
```

Apply:

```bash
bin/rails legacy_exchange_return_backfill:consolidation_apply DRY_RUN=false OUTPUT=tmp/legacy_exchange_return_consolidation_apply.json
```

Apply specific exchange-return ids only:

```bash
bin/rails legacy_exchange_return_backfill:consolidation_apply IDS=1806,1807,1808 DRY_RUN=false OUTPUT=tmp/legacy_exchange_return_consolidation_apply.json
```
