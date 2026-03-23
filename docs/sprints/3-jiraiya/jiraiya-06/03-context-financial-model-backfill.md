# JIRAIYA-06 Slice 2: Financial Model Backfill

## Goal

Move the financial schema to `context` ownership before changing runtime
controller and service behavior.

## Delivered

Required `context_id` and backfill to each user's main context for:

- `CashTransaction`
- `CardTransaction`
- `Budget`
- `Investment`
- `Subscription`
- `Reference`

## Backfill Rule

For each migration:

1. ensure the user has a main context
2. assign existing records to that main context
3. make `context_id` non-null

## Runtime Safety

Each migrated model also gained default-context assignment so new records created
through the app automatically attach to `user.ensure_main_context!` unless a
specific context is already present.

## Constraint

Slice 2 was still schema-first.

The app remained mostly user-scoped in:

- controllers
- finder services
- recalculation services
- reference/payment flows

## Result

At the end of Slice 2, the financial schema was fully context-owned, but the
application behavior still needed a full migration to `current_context`.
