# NARUTO-04 — Income subscriptions and bulk operations: product and data contract

## Status

Planning refresh — 2026-10-15. Product decisions are locked below; implementation and manual verification are pending.

## Goal

Represent recurring income alongside recurring expenses in the existing Subscription workflow, support safe bulk status/allocation edits, and verify that all affected audit operations can be rolled back.

This is a subscription grouping workflow, not a scheduler. Users still create, attach, or edit actual cash/card transactions; their signed installments remain the financial source of truth.

## Verified baseline

- `Subscription` uses `finance_subscriptions`; `status` is already a string-backed enum (`active`, `paused`, `finished`). It owns linked cash/card transactions and category/entity allocation joins.
- `Subscription#refresh_price!` derives `price` from the **signed sum** of linked cash/card transaction prices. The form's Stimulus controller also sums signed row prices. The column is skipped by financial auditing and recalculated on rollback. The previous proposal to store every subscription price as positive conflicts with this implementation.
- The transaction-creation modal currently defaults to **card** and a **negative** price. The linked-transaction sync copies subscription description, comment, category/entity allocations, and a built-in `SUBSCRIPTION` category to transactions and syncs their installments. Changing subscription allocations can therefore mutate linked transaction allocations; it is not just a label edit.
- Subscription category/entity associations may hold multiple records even though the form exposes a single selection. A bulk action must define whether it replaces or adds allocations; direct `update_all` would bypass the sync and audit paths.
- Monthly analysis classifies **installment price sign**, not subscription kind. The kind should describe an intended direction and UI grouping; it must not reclassify a real negative transaction as income.
- `User#create_built_ins` creates `SUBSCRIPTION`, but does **not** create `SALARY` or `SALARIO`. `Category#name` translates a built-in from its stored `category_name` (for example, `SALARIO` uses the `salario` locale key). Both keys need en/pt-BR translations.
- `Category#validate_built_in_hierarchy` currently forbids all built-in parents. `Category#parent?` is inferred from the presence of children, while NARUTO-01 permits selecting parents directly. The two OTHER built-ins need a narrow exception to allow custom children; they remain selectable themselves, including before they have children.
- `Audit::Rollback::Adapters::Subscription` and `spec/services/audit/rollback/subscription_adapter_spec.rb` already exist. The adapter ignores derived price/counts and discovers linked transactions and allocation joins as dependencies. Current specs cover a linked metadata update, restoration of a destroyed empty subscription, and a create rollback conflict after a later dependent appears; they do not yet cover every NARUTO-04 path.
- `ApplicationController` wraps mutating requests in an `Audit::Operation` (`source: :web`). `AuditOperation` has source and scalar metadata, **not** an `operation_kind` column. A bulk edit can share the request's operation and tag its metadata; a new column is not part of this plan.

## Feature 1 — Income subscription

Add `subscription_kind varchar NOT NULL DEFAULT 'expense'` to `finance_subscriptions`, with a string-backed enum of `expense` and `income`. Existing records remain expense. Validate the enum; consider a database check constraint so invalid direct writes are also rejected.

The kind indicates the user's recurring intent. Actual transactions and installments retain their signed amounts, and `Subscription#price` remains their **signed sum**. New income-linked cash rows default to positive amounts; expense-linked cash/card rows default to negative. Income subscriptions are **cash-only** in V1: the form must not offer a card row and the server must reject a card-linked income subscription. Card cashback/positive card income is deferred. After creation, `subscription_kind` is immutable—even when the subscription has no linked transactions. A user may change category only within the same expense/income kind; never rewrite historical prices or paid installments.

Display kind clearly on subscription index, show, and form in both desktop and PWA. Localize labels in en and pt-BR. Keep `status` independent from kind; paused/finished income subscriptions stay income subscriptions. The derived total should be described as a signed linked-transaction total, not a guaranteed positive recurring amount or projected salary. A recurring expected amount would require a separate data field and decision, not a reinterpretation of the current `price` column.

Category behavior: add salary as a built-in category. Preserve the existing first user's `SALARY` category and second user's `SALARIO` category **in place**, changing `built_in` to true without changing IDs or losing allocations. Create a `SALARIO` built-in for the third user, who lacks one. For existing users in other environments, reconcile by existing `SALARY`/`SALARIO` names first, preserve their IDs/allocations, and create a locale-appropriate category only if neither exists. New users receive `SALARY` for English and `SALARIO` for pt-BR via `User#create_built_ins`. Both stored names must display as “Salary” in en and “Salário” in pt-BR via `salary` and `salario` locale keys; changing a user's UI locale should not require renaming database rows. If a user already has **both** categories, do not automatically merge or delete them; flag the duplicate for an explicit resolution. The backfill must be idempotent and must not rely on `User.first` ordering or hard-coded production IDs.

The form's initial category/type choice is a deliberate four-path choice, not a generic income toggle plus a salary default:

| Form choice | Subscription kind | Stored category or category family |
|---|---|---|
| SUBSCRIPTION (Expense) | `expense` | existing `SUBSCRIPTION` built-in |
| SALARY (Income) | `income` | user's `SALARY`/`SALARIO` built-in |
| OTHER (Expense) | `expense` | new `OTHER` parent and its selectable children |
| OTHER (Income) | `income` | new **real** `OTHER INCOME` parent and its selectable children |

`OTHER` and `OTHER INCOME` are localized built-in **parent categories**: they are always top-level, and users may also assign them directly, including when they have no children. Their labels may read “Other (Expense)” and “Other (Income)” in the subscription form, but the latter is stored as `OTHER INCOME`, not as a synthetic UI option. Reconcile an existing same-name top-level category in place where safe; do not create a duplicate or disturb its direct allocations. Users can add ordinary custom child categories, such as `Freelance` under `OTHER INCOME` or `Rent` under `OTHER`, and those children appear under the matching choice in the subscription form. Permit custom children under these two built-ins without broadly allowing children under all built-ins. Preserve two-level depth, same-user ownership, localized parent/child display, direct parent allocations, and parent-subtree filtering. Their child categories do **not** gain an income/expense checkbox or generic direction rule in the category form; their subscription-form grouping comes only from these two known parent IDs.

For V1, the four choices and any existing children should be usable; adding more children should update the list without further hard-coded form changes. Selecting OTHER itself is valid with zero children. The chosen SALARY/OTHER parent/OTHER child category **replaces** the automatic `SUBSCRIPTION` category on linked transactions; `SUBSCRIPTION` is applied only for the SUBSCRIPTION (Expense) path. Changing OTHER (Expense) to Rent (Expense), or OTHER (Income) to Freelance (Income), changes the subscription and linked transaction category through the existing audited allocation-sync path while keeping the kind fixed. Do not force SALARY for rent/freelance income. Monthly analysis continues to use signed installments, not the chosen category or kind, to determine cash-flow direction.

Existing subscription category/entity allocation behavior and sync must be audited before replacing the automatic `SUBSCRIPTION` tag, so unrelated historical allocations are not silently deleted. A same-kind category change with linked transactions is allowed, but must respect paid-history and other financial-safety guards; a rejected change leaves both subscription and linked transaction allocations untouched. Cross-kind category selection and any persisted kind change are blocked.

## Feature 2 — Bulk edit

Select subscriptions on the desktop index and PWA cards. Show a localized bulk-action control when at least one row is selected. A submitted action changes **one field** for all selected subscriptions: status, category, or entity. Selection consists of explicit IDs, not every record matching the current filter. On a filtered page, do not act on hidden/unselected rows. Preserve the user's current index/filter destination on success and failure.

The server must load all IDs through `current_context.subscriptions` and reject missing, foreign-user, other-context, duplicated/invalid, or oversized selections rather than partially applying a request. Validate the chosen field/value against a strict allowlist and load category/entity from the current user's own records. Category/entity edits **replace** the existing allocation set, with an explicit clear action rather than an implicit blank value. The chosen category must be valid for each subscription's kind/family; changing category must not silently change kind. All selected subscriptions must be validated and updated in one database transaction: if one fails a financial/history/allocation rule, none are changed. Avoid direct SQL bulk updates, which bypass callbacks, join changes, per-record audit versions, and linked-transaction synchronization.

Status changes must follow the existing lifecycle transition rules rather than bypassing them with arbitrary `status=` writes. A requested event that is invalid for **any** selected subscription rejects the **entire** batch; the server independently validates that rule. A bulk category/entity action must use the established subscription-allocation mutation path so linked transactions and their audit versions remain consistent.

Use the request's existing `Audit::Operation` as one operation for the whole atomic change; record an identifying scalar metadata value such as `subscription_bulk_edit` if needed for the timeline. Each changed subscription and any changed allocations/linked transactions produce their normal `AuditVersion` rows under that operation. No `operation_kind` column is presumed. A no-op should not create a misleading financial audit entry.

The audit timeline should present a single rollback action for the operation. Preview must include every affected subscription and dependent row. Apply uses the existing operation-level rollback mechanism atomically; it must respect later-dependency conflicts and paid-history rules. Do not promise that an operation can always be undone merely because its individual adapters exist.

For UI updates, prefer a regular Turbo navigation/refresh that keeps filters and selection state predictable. Row-level Turbo replacement can be added if its filtered-table and mobile-card behavior is tested; it is not required by the product contract.

## Feature 3 — Rollback verification

Extend the existing `spec/services/audit/rollback/subscription_adapter_spec.rb` rather than creating a duplicate `adapters/subscription_spec.rb` path. Verify:

1. Create rollback removes an empty subscription and its allocation joins, while a later linked transaction produces a conflict.
2. Metadata, status, kind, and allocation updates restore prior values and any dependent transaction mutations.
3. Destroy rollback restores an empty subscription and joins, with no linked-transaction deletion implied.
4. One bulk operation previews/applies as one rollback, restoring every selected record (and related allocations/transactions) or none.
5. Intervening changes, paid-history constraints, foreign contexts, and unsupported dependencies surface conflicts or prohibitions instead of partial rollback.

## Non-goals

- Automatically generating recurring transactions on a schedule.
- Start/end date enforcement, proration, or salary splitting across bank accounts.
- Reclassifying historical financial reports by subscription kind independent of signed installments.
- Silently rewriting linked historical prices when kind changes.
- Forcing every income subscription into the salary category, including rental/freelance income.
- General income/expense flags on all categories or category-form direction checkboxes; only the two known OTHER parent families group their children in this feature.
- Bulk deletion or bulk attachment/detachment of transactions.

## Locked decisions

1. Keep `Subscription#price` as a signed derived sum. Do not classify monthly income/expense solely from `subscription_kind`.
2. Income subscriptions are cash-only in V1; card cashback-style income is deferred.
3. Bulk category/entity edits replace allocations and offer an explicit clear action.
4. A persisted subscription's kind cannot change at all; category changes within its existing kind remain allowed, including with linked transactions subject to financial-safety checks.
5. Reject a mixed-state bulk status action atomically if the requested transition is invalid for any selected row.
6. Replace the former salary-suggestion concept with the four subscription choices above and expandable OTHER child lists. Do not add general category direction flags. Both OTHER parents are directly selectable; the chosen category replaces the automatic `SUBSCRIPTION` tag except for the SUBSCRIPTION (Expense) path.

Implementation order and acceptance tests: [02-implementation-slices.md](02-implementation-slices.md).
