# JIRAIYA-06 Slice 1: Context Foundation

## Goal

Introduce `Context` as the mandatory financial owner for scenario planning without
changing the runtime query model yet.

## Delivered

- `Context` model with lineage-oriented fields
- one mandatory main context per user
- user-level helpers to resolve or create the main context safely
- base associations from `User` to `contexts`

## Implemented Shape

### Context

- belongs to `user`
- optional `source_context`
- `derived_contexts`
- `main` flag
- `cloned_at`
- `archived_at`

### User

- `has_many :contexts`
- `main_context`
- `ensure_main_context!`
- automatic main-context creation for new users

## Constraint

Slice 1 intentionally did not move financial reads or writes to `context`.
It only established the domain object and the invariant that each user always
has one main context available.

## Result

At the end of Slice 1, the app had a valid `Context` foundation but was still
behaviorally user-scoped.
