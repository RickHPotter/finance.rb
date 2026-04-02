# JIRAIYA-04: Standalone EXCHANGE RETURN Parent Reference Runner

## Purpose

This runner fills `CashTransaction.reference_transactable` for standalone
`EXCHANGE RETURN` cash transactions that are still missing their immediate parent.

The parent is derived from the linked standalone monetary `Exchange` rows:

- `exchange.entity_transaction.transactable`

This is the canonical parent for standalone exchange-return projections.

## Scope

Included:

- `CashTransaction.exchange_return`
- `reference_transactable = nil`
- has monetary exchanges
- all monetary exchanges have `bound_type == "standalone"`
- all linked standalone monetary exchanges resolve to the same parent transactable

Excluded:

- `card_bound` exchange returns
- mixed bound-type exchange sets
- rows with more than one unique parent transactable
- rows whose parent does not resolve to an `EXCHANGE` source transaction

## Why This Is Safe

The runtime already treats the linked `Exchange -> EntityTransaction -> transactable`
chain as the structural source of truth for standalone exchange-return projections.

This runner only materializes that parent onto `reference_transactable` when the
linked exchange rows are unambiguous.

## Important Nuance

This runner is not message-family based.

It does not decide which sender-side exchange return should anchor a receiver-side
borrow return. It only fills the missing immediate parent edge for the standalone
`EXCHANGE RETURN` cash transaction itself.

## Audit Behavior

The audit reports:

- the exchange-return transaction id
- current reference
- desired reference
- linked standalone exchange ids
- all resolved parent candidates
- whether the row is supported for apply

Unsupported reasons include:

- `missing_standalone_monetary_exchanges`
- `parent_candidates_not_found`
- `multiple_parent_candidates`
- `parent_not_exchange_source`

## Apply Behavior

The apply step:

- locks the target `CashTransaction`
- verifies the reference is still blank
- writes the resolved parent into `reference_transactable`

It does not:

- rewrite receiver-side chains
- infer ambiguous parent choices
- touch `card_bound` exchange returns

## Tooling

Read-only audit:

```bash
bin/rails standalone_exchange_parent_reference:audit
```

Dry run:

```bash
bin/rails standalone_exchange_parent_reference:apply DRY_RUN=true
```

Apply:

```bash
bin/rails standalone_exchange_parent_reference:apply DRY_RUN=false
```

Apply specific exchange-return ids only:

```bash
bin/rails standalone_exchange_parent_reference:apply IDS=4735,4736 DRY_RUN=false
```
