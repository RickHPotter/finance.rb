# NARUTO-04 — Income subscriptions and bulk operations: product and data contract

## Status

Implementation complete, verification pending — 2026-10-16. The salary/OTHER foundation, kind/main-category forms, bulk edit, and rollback hardening are implemented and locally verified with focused specs. Full CI and manual desktop/PWA financial-history flows remain before declaring NARUTO-04 done.

## Goal

Represent recurring income alongside recurring expenses in the existing Subscription workflow, support safe bulk status/allocation edits, and verify that all affected audit operations can be rolled back.

This is a subscription grouping workflow, not a scheduler. Users still create, attach, or edit actual cash/card transactions; their signed installments remain the financial source of truth.

## Verified baseline

- `Subscription` uses `finance_subscriptions`; `status` is already a string-backed enum (`active`, `paused`, `finished`). It owns linked cash/card transactions and category/entity allocation joins.
- `Subscription#refresh_price!` derives `price` from the **signed sum** of linked cash/card transaction prices. The form's Stimulus controller also sums signed row prices. The column is skipped by financial auditing and recalculated on rollback. The previous proposal to store every subscription price as positive conflicts with this implementation.
- Before Slice 2, the transaction-creation modal defaulted to **card** and a **negative** price. The linked-transaction sync copied subscription description, comment, category/entity allocations, and an automatic built-in `SUBSCRIPTION` category to transactions and synced their installments. That automatic category was the implicit **main category**; the pre-existing category field remains an **additional category** (e.g. Netflix has main SUBSCRIPTION and additional LEISURE). Changing either can mutate linked transaction allocations; it is not just a label edit.
- Subscription category/entity associations may hold multiple records even though the form exposes a single additional-category selection. NARUTO-04 keeps the extra category optional and limited to one through the form/API; it does not reinterpret existing arbitrary categories as main categories. Direct `update_all` would bypass sync and audit paths.
- Monthly analysis classifies **installment price sign**, not subscription kind. The kind should describe an intended direction and UI grouping; it must not reclassify a real negative transaction as income.
- Slice 1 added and localized `SALARY`/`SALARIO`, `OTHER`, and `OTHER INCOME` built-ins, preserving existing salary category IDs. `Category#name` translates either salary key. `SUBSCRIPTION`, salary, and both OTHER categories are the four **main-category families**; each can have custom children, and each parent remains directly selectable.
- Local development has expense subscriptions with additional categories such as `BILL`, `LEISURE`, `PRODUCTIVITY`, and `INSURANCE`. Those existing allocations stay where they are. Their main category is the current automatic `SUBSCRIPTION` tag on linked transactions, not the additional category shown in the form.
- `Audit::Rollback::Adapters::Subscription` and `spec/services/audit/rollback/subscription_adapter_spec.rb` already exist. The adapter ignores derived price/counts and discovers linked transactions and allocation joins as dependencies. Current specs cover a linked metadata update, restoration of a destroyed empty subscription, and a create rollback conflict after a later dependent appears; they do not yet cover every NARUTO-04 path.
- `ApplicationController` wraps mutating requests in an `Audit::Operation` (`source: :web`). `AuditOperation` has source and scalar metadata, **not** an `operation_kind` column. A bulk edit can share the request's operation and tag its metadata; a new column is not part of this plan.

## Feature 1 — Income subscription

Add `subscription_kind varchar NOT NULL DEFAULT 'expense'` to `finance_subscriptions`, with a string-backed enum of `expense` and `income`. Add a `main_category_id` FK to `categories`, distinct from the existing `category_transactions` used for the optional additional category. Existing records remain expense and are backfilled to their user's built-in `SUBSCRIPTION` as main; their current category joins remain untouched. New records require a valid owned main category. Keep the main category explicit even if it is a child, so a child selected as main can be distinguished from an additional category. Validate the enum and main-category ownership/family; consider a database check constraint for kind values.

The kind indicates the user's recurring intent. Actual transactions and installments retain their signed amounts, and `Subscription#price` remains their **signed sum**. New income-linked cash rows default to positive amounts; expense-linked cash/card rows default to negative. Income subscriptions are **cash-only** in V1: the form must not offer a card row and the server must reject a card-linked income subscription. Card cashback/positive card income is deferred. After creation, `subscription_kind` is immutable—even when the subscription has no linked transactions. A user may change **main** category only within the same expense/income kind, and may change the optional additional category to any category; never rewrite historical prices or paid installments.

Display kind clearly on subscription index, show, and form in both desktop and PWA. Localize labels in en and pt-BR. Keep `status` independent from kind; paused/finished income subscriptions stay income subscriptions. The derived total should be described as a signed linked-transaction total, not a guaranteed positive recurring amount or projected salary. A recurring expected amount would require a separate data field and decision, not a reinterpretation of the current `price` column.

Category behavior: add salary as a built-in category. Preserve the existing first user's `SALARY` category and second user's `SALARIO` category **in place**, changing `built_in` to true without changing IDs or losing allocations. Create a `SALARIO` built-in for the third user, who lacks one. For existing users in other environments, reconcile by existing `SALARY`/`SALARIO` names first, preserve their IDs/allocations, and create a locale-appropriate category only if neither exists. New users receive `SALARY` for English and `SALARIO` for pt-BR via `User#create_built_ins`. Both stored names must display as “Salary” in en and “Salário” in pt-BR via `salary` and `salario` locale keys; changing a user's UI locale should not require renaming database rows. If a user already has **both** categories, do not automatically merge or delete them; flag the duplicate for an explicit resolution. The backfill must be idempotent and must not rely on `User.first` ordering or hard-coded production IDs.

The form's **main category** choice is a four-family selector, not the existing additional-category input. Each family offers its built-in parent and any user-created children:

| Form choice | Subscription kind | Stored category or category family |
|---|---|---|
| SUBSCRIPTION (Expense) | `expense` | `SUBSCRIPTION` or a child such as SUBSCRIPTION → Leisure |
| SALARY (Income) | `income` | user's `SALARY`/`SALARIO` or one of its children |
| OTHER (Expense) | `expense` | real `OTHER` parent or one of its children |
| OTHER (Income) | `income` | real `OTHER INCOME` parent or one of its children |

All four families are localized built-in **parent categories**: they are top-level and directly selectable even with no children. Their children are ordinary user-created categories. `OTHER INCOME` is a real stored category, not a synthetic UI option. Users may create `Freelance` under `OTHER INCOME`, `Rent` under `OTHER`, or `Leisure` under `SUBSCRIPTION`; selecting a child as main applies that child **only**, not its parent. Permit custom children under these four families without broadly allowing children under unrelated built-ins. Preserve two-level depth, same-user ownership, localized parent/child display, direct parent allocations, and parent-subtree filtering. Children do **not** gain general income/expense flags or direction rules in the Category form; main-category family membership comes from ancestry. A category from any family can still be chosen as an **additional** category, without implying direction.

For V1, the four families and any existing children should be usable; adding a child updates the list without hard-coded form changes. The chosen main category **replaces** the automatic `SUBSCRIPTION` category on linked transactions. The linked transaction receives the main category plus at most one optional additional category, with duplicate IDs collapsed. Netflix can therefore have main `SUBSCRIPTION` and additional `LEISURE`; salary can have main `SALARY`/`SALARIO` and no additional category. Changing OTHER (Expense) to Rent (Expense), or SUBSCRIPTION (Expense) to SUBSCRIPTION → Leisure (Expense), updates the main category on the subscription and linked transactions without changing kind. Do not force SALARY for rent/freelance income. Monthly analysis continues to use signed installments, not category or kind, to determine cash-flow direction.

The existing subscription `category_transactions` remain the additional category; backfilling main `SUBSCRIPTION` does not move or delete them. The linked-transaction sync and the guards in `HasSubscription` and `AllocationMutations::FormCoordinator` currently hard-code `SUBSCRIPTION`; they must use the subscription's effective main category while preserving its additional category. A same-kind main or additional category change with linked transactions is allowed, subject to paid-history and other financial-safety guards; a rejected change leaves both subscription and linked allocations untouched. Cross-kind **main** selection and any persisted kind change are blocked. Additional categories remain unrestricted by kind.

For a subscription-linked composite transaction, the main category is a management
marker on the parent transaction, not an input to line-item reporting; it does not
override each `LineItem`'s independent category. NARUTO-02's rule that a selected
line-item category must be a leaf still
applies. An OTHER/SUBSCRIPTION/salary parent chosen as the subscription main category
therefore does not become a line-item category automatically. Cover this boundary in
the linked-transaction and rollback tests.

## Feature 2 — Bulk edit

Select subscriptions on the desktop index and PWA cards. Show a localized bulk-action control when at least one row is selected. A submitted action changes **one field** for all selected subscriptions: status, **additional category**, or entity. Main-category edits stay in the individual form because they encode kind/family and linked-transaction management. Selection consists of explicit IDs, not every record matching the current filter. On a filtered page, do not act on hidden/unselected rows. Preserve the user's current index/filter destination on success and failure.

The server must load all IDs through `current_context.subscriptions` and reject missing, foreign-user, other-context, duplicated/invalid, or oversized selections rather than partially applying a request. Validate the chosen field/value against a strict allowlist and load category/entity from the current user's own records. Additional-category/entity edits **replace** the existing allocation set, with an explicit clear action rather than an implicit blank value. Additional category may be any owned selectable category regardless of kind; bulk edit must not change `main_category_id` or `subscription_kind`. All selected subscriptions must be validated and updated in one database transaction: if one fails a financial/history/allocation rule, none are changed. Avoid direct SQL bulk updates, which bypass callbacks, join changes, per-record audit versions, and linked-transaction synchronization.

Status changes must follow the existing lifecycle transition rules rather than bypassing them with arbitrary `status=` writes. A requested event that is invalid for **any** selected subscription rejects the **entire** batch; the server independently validates that rule. A bulk category/entity action must use the established subscription-allocation mutation path so linked transactions and their audit versions remain consistent.

Use the request's existing `Audit::Operation` as one operation for the whole atomic change; record an identifying scalar metadata value such as `subscription_bulk_edit` if needed for the timeline. Each changed subscription and any changed allocations/linked transactions produce their normal `AuditVersion` rows under that operation. No `operation_kind` column is presumed. A no-op should not create a misleading financial audit entry.

The audit timeline should present a single rollback action for the operation. Preview must include every affected subscription and dependent row. Apply uses the existing operation-level rollback mechanism atomically; it must respect later-dependency conflicts and paid-history rules. Do not promise that an operation can always be undone merely because its individual adapters exist.

For UI updates, prefer a regular Turbo navigation/refresh that keeps filters and selection state predictable. Row-level Turbo replacement can be added if its filtered-table and mobile-card behavior is tested; it is not required by the product contract.

## Feature 3 — Rollback verification

Extend the existing `spec/services/audit/rollback/subscription_adapter_spec.rb` rather than creating a duplicate `adapters/subscription_spec.rb` path. Verify:

1. Create rollback removes an empty subscription and its allocation joins, while a later linked transaction produces a conflict.
2. Metadata, status, kind, main category, and additional allocation updates restore prior values and any dependent transaction mutations.
3. Destroy rollback restores an empty subscription and joins, with no linked-transaction deletion implied.
4. One bulk operation previews/applies as one rollback, restoring every selected record (and related allocations/transactions) or none.
5. Intervening changes, paid-history constraints, foreign contexts, and unsupported dependencies surface conflicts or prohibitions instead of partial rollback.

## Non-goals

- Automatically generating recurring transactions on a schedule.
- Start/end date enforcement, proration, or salary splitting across bank accounts.
- Reclassifying historical financial reports by subscription kind independent of signed installments.
- Silently rewriting linked historical prices when kind changes.
- Forcing every income subscription into the salary category, including rental/freelance income.
- General income/expense flags on all categories or category-form direction checkboxes; only the four known main-category families determine kind when used as main.
- Bulk deletion or bulk attachment/detachment of transactions.

## Locked decisions

1. Keep `Subscription#price` as a signed derived sum. Do not classify monthly income/expense solely from `subscription_kind`.
2. Income subscriptions are cash-only in V1; card cashback-style income is deferred.
3. Bulk **additional-category**/entity edits replace allocations and offer an explicit clear action. Main-category edits are individual only.
4. A persisted subscription's kind cannot change at all; main-category changes within its existing kind and unrestricted additional-category changes remain allowed, including with linked transactions subject to financial-safety checks.
5. Reject a mixed-state bulk status action atomically if the requested transition is invalid for any selected row.
6. Use the four main-category families above, each parent directly selectable and each able to have custom children. A selected child stands alone as main; its parent is not also attached. Keep one optional additional category, which may be any category and does not affect kind.

Existing subscriptions need no category reparenting: their current category join is the additional category, and the main category backfill is `SUBSCRIPTION`. A future generic income/expense category flag or broader main-category-family editor is outside this feature.

Implementation order and acceptance tests: [02-implementation-slices.md](02-implementation-slices.md).
