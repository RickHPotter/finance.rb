# KAKASHI-08 Callback-Bypass Inventory

## Scope

This inventory covers application writes that bypass Active Record lifecycle callbacks
and therefore cannot rely on PaperTrail callbacks. It was reviewed when Slice 4 enabled
the complete initial financial model scope.

## Audited Bypasses

| Path | Financial data | Treatment |
| --- | --- | --- |
| transaction controllers and projection concerns | canonical transaction, installment, allocation, and exchange fields | `Audit::BulkMutation` captures changes before direct updates, inserts, or deletes |
| `Reference` and `UserCard` billing synchronization | canonical reference, transaction, installment, and exchange dates | `Audit::BulkMutation` records every changed row under `reference_sync` |
| import services | canonical imported transaction and installment dates and paid state | `Audit::BulkMutation` preserves import source and before-state |
| budget bulk update | active state, budget period, and other permitted canonical fields | each selected budget is versioned before the bulk write |
| linter and admin repairs | any allowlisted repair attribute on an audited model | `Audit::BulkMutation` versions audited records and preserves legacy direct writes for out-of-scope records |
| context clone | callback-free copies of every audited model | `Audit::BulkMutation.insert!` creates equivalent create versions; unaudited context and join rows remain direct inserts |
| context purge | callback-free deletion of every audited row in the context | rows are loaded and versioned before deletion; Piggy Bank links are deleted before their transactions |
| Piggy Bank projection | return routing ID changes | `Audit::BulkMutation` records the canonical link change under `piggy_bank_sync` |
| exchange chain repair | polymorphic reference routing | `Audit::BulkMutation` records the canonical reference change under `reference_sync` |

## Intentional Derived-Field Exclusions

These writes remain callback-free because every affected attribute is recalculable and
is explicitly skipped from version payloads:

- `Logic::RecalculateBalancesService`: installment and budget `balance`/`order_id`
- budget `remaining_value`: spend-derived amount recomputed from the canonical budget value and allocations
- `Logic::RecalculateCountAndTotalService`: user-card and bank-account cached totals
- counter-cache maintenance: transaction, installment, and exchange counts
- `Subscription#refresh_price!`: aggregate subscription price
- context-purge counter refresh: account, card, and subscription counts
- category/entity count and total refresh: models outside the initial audit scope

Changing any of these paths to write a canonical attribute requires routing it through
`Audit::BulkMutation` and adding a regression spec.

## Out-of-Scope Direct Writes

- user locale selection
- conversation/message read and supersession state
- `Context`, `BudgetCategory`, and `BudgetEntity` clone/purge rows
- category and entity cached totals

These models are not part of the KAKASHI-08 initial financial audit scope. Their direct
writes must be reconsidered if a later slice adds them to that scope.

## Metadata Allowlist

`Audit::VersionMetadata::ALLOWED_ATTRIBUTES` is the only source of per-version routing
metadata. Values come from persisted model attributes and are limited to scalar IDs and
polymorphic type names. Descriptions, request parameters, headers, cookies, exceptions,
and arbitrary objects are never copied into metadata.
