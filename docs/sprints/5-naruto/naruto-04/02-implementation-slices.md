# NARUTO-04 — Implementation slices and acceptance matrix

This plan starts after the product decisions in [the contract](01-product-and-data-contract.md) are resolved. Each slice should be implemented, tested, and committed separately. Do not begin bulk mutation before the kind/sign contract is stable.

## Slice 0 — Baseline and decisions

- The product decisions are locked in the contract. Align the NARUTO-04 summary in `SPRINT_5.md` before implementation.
- Capture baseline specs for current signed derived totals, linked cash/card sync, lifecycle transitions, and adapter rollback. Confirm no migration or UI code has already landed on this branch.
- Trace subscription-linked transaction attach/detach flows and allocation restrictions before changing callback behavior.

Done when the contract has no implementation-blocking ambiguity and the baseline specs pass.

## Slice 1 — Salary/OTHER built-ins and data reconciliation

Status: implemented and locally verified on 2026-10-15. The existing `SALARY`/`SALARIO` records for users 1 and 4 kept IDs 24 and 105; user 5 received `SALARIO`. All three received `OTHER` and `OTHER INCOME`. Focused category/user/migration/request specs passed (108 examples). This is not a claim about HMG/PROD data.

- Add `salary` and `salario` built-in category translations in en and pt-BR; verify `Category#name` displays either stored key in the active locale. Add salary to the normal built-in category presentation (including colour/icon conventions where relevant).
- Backfill existing users safely: mark their existing `SALARY` or `SALARIO` category built-in in place; create the locale-appropriate one only when neither exists. Preserve IDs, category transaction joins, colours and other metadata. Handle a user with both names explicitly rather than silently merging.
- In the current three-user development data, this means: first user's `SALARY` becomes built-in, second user's `SALARIO` becomes built-in, and third user gets a new `SALARIO` built-in. Identify users by durable attributes or inspect their existing categories and locale; do not encode `.first/.second/.third` ordering in a migration.
- Add the appropriate built-in for new users through `User#create_built_ins` (English `SALARY`; pt-BR `SALARIO`). Make the reconciliation idempotent and safe across HMG/PROD datasets that may not have exactly three users.
- Add real localized `OTHER` (Expense) and `OTHER INCOME` (Income) built-ins for existing and new users. Reconcile same-name top-level categories in place, preserving any direct allocations. Add a narrow exception to the built-in hierarchy validation so users can add custom children under these two parents, without allowing children under unrelated built-ins or allowing built-in children. The Category form must offer these parents; ordinary NARUTO-01 parent behavior stays unchanged.
- Keep both OTHER parents directly selectable, even when childless, on subscriptions and ordinary transaction forms. Keep parent-subtree filtering so queries on the parent include direct and child allocations. Do not add general income/expense flags to categories.

Acceptance: existing category links are unchanged; no duplicate salary category is created; all three development users have the intended salary category; en/pt-BR display changes with locale while stored names stay stable; repeat run makes no further changes; new users get the right built-ins; OTHER parents and their custom children are both selectable.

Tests: category/user model specs, data backfill tests for both existing names/missing/both-name cases, translation checks, existing allocation preservation, direct OTHER allocation, permitted OTHER children, forbidden children under other built-ins, childless-parent selection, and parent-subtree filters.

## Slice 2 — Kind data and forms

- Add the `subscription_kind` migration with expense default, string enum, model validation, factory trait, and schema annotations.
- Add a localized four-path choice to create/edit: SUBSCRIPTION (Expense), SALARY (Income), OTHER (Expense), OTHER (Income). The two OTHER paths expose their existing children and must stay expandable as users add children, without editing the form's hard-coded options. The income/expense kind and selected category must be saved together and validated together. Show kind/family on desktop/PWA index and show.
- Make new linked transaction defaults match kind: positive cash for income, negative cash/card for expense. Income is cash-only: hide card creation and reject card-linked income server-side, including nested attributes and attach flows. Preserve explicit sign changes only if they remain valid for the chosen kind.
- Make the selected category replace automatic `SUBSCRIPTION` tagging on linked transactions, except for the SUBSCRIPTION (Expense) path. Both OTHER parents and their children can be selected. A same-kind switch from OTHER to one of its children updates existing linked allocations through the audited sync path, subject to financial-safety checks. Do not manufacture a general category-direction constraint.
- Block changing kind after creation, even with no linked transactions; reject cross-kind category choices. Keep the derived `price` signed. Never rewrite existing linked prices as an incidental result of a form edit.

Acceptance: all four paths are displayed and localized; newly added OTHER children appear in the correct path; childless OTHER can be selected; new income records can create a positive cash transaction with positive installment; income card entries fail on the server; all persisted kind changes fail; same-kind category changes update linked allocations without changing prices; salary built-in works in either locale; en/pt-BR and desktop/PWA are covered.

Tests: migration/model, request create/update/authorization, immutable kind, category-family compatibility, linked cash/card transaction and installment specs, attach-flow rejection for income cards, same-kind category replacement and rollback, feature flow for all four options and dynamic children, monthly-analysis regression for positive/negative installment classification.

## Slice 3 — Bulk edit server contract

- Add a strict endpoint and mutation service for explicit selected IDs, one allowlisted action/value, context/owner validation, and an upper selection bound.
- Use one database transaction and the request's existing audit operation. For status, reuse `Logic::Subscriptions::LifecycleTransition` or an equivalent validated shared transition path. For allocations, use the same safe model/association mutation path as single edits.
- Reject the entire set if one row is invalid, stale, foreign, uses an incompatible category family, or conflicts with linked financial history. Category/entity actions replace allocations; clearing either is an explicit action. Return localized actionable errors.
- Tag the operation with scalar metadata if useful; do not invent an `operation_kind` column.

Acceptance: a successful batch creates one operation with versions for all changed rows; one invalid row causes zero changes; other-context and foreign IDs are never mutated; no-op and duplicate-ID requests behave predictably; linked transaction allocations and audit versions stay consistent.

Tests: request/service specs for all actions, authorization, atomicity, mixed-state rejection, empty/oversized selection, explicit clear and replacement semantics, category-family compatibility, and linked cash/card allocation effects.

## Slice 4 — Desktop/PWA bulk controls

- Add selection controls and a localized action bar to both subscription index presentations. Give mobile cards usable selection affordances without obscuring existing edit links.
- Maintain selection through ordinary index interaction only as far as it remains visible and explicit; clear it on filter/context changes rather than accidentally acting on hidden rows.
- Keep the user's index destination and filters after success/failure. Use normal Turbo navigation first; add stream-based row replacement only if behavior is equivalent and tested for both layouts.

Acceptance: one and multiple selection, cancel/clear, filter change, keyboard access, mobile touch, light/dark mode, and localized errors work without affecting non-selected records.

Tests: feature coverage for desktop and mobile layouts, plus request coverage for redirects or Turbo responses.

## Slice 5 — Rollback hardening

- Extend `spec/services/audit/rollback/subscription_adapter_spec.rb` for kind, create, update, destroy, allocation sync, and operation-level bulk rollback.
- Fix adapter/dependency/recalculation gaps discovered by those tests without weakening preview checks.
- Verify an intervening mutation, linked later dependency, or paid-history conflict prevents partial restoration.

Acceptance: bulk apply restores all affected records and dependencies atomically when previewable; conflicts are explicit; derived totals are recomputed rather than restored from stale snapshots.

## Final verification and manual test

- Run focused model, request, service, and feature specs; `bin/rubocop -A`; relevant JS build. Then run `bin/ci` before merge.
- Manually create subscriptions through all four choices, create an OTHER child and confirm it appears, add a recurring cash row, inspect index/show/monthly analysis, bulk-edit a mix of subscriptions, preview/undo the bulk operation, and verify paid-history protection.
- Record any remaining limitation in this contract and in `SPRINT_5.md`; do not call NARUTO-04 complete on code/specs alone if the manual flows remain untested.
