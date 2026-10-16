# NARUTO-04 — Implementation slices and acceptance matrix

The product contract is locked. Each remaining slice should be implemented, tested, and committed separately. Do not begin bulk mutation before the main/additional-category and kind contracts are stable.

## Slice 0 — Baseline and decisions

- The product decisions are locked in the contract. Align the NARUTO-04 summary in `SPRINT_5.md` before implementation.
- Capture baseline specs for current signed derived totals, linked cash/card sync, lifecycle transitions, and adapter rollback. Slice 1's category migration/UI has already landed; do not repeat it.
- Trace subscription-linked transaction attach/detach flows and allocation restrictions before changing callback behavior.

Done when the contract has no implementation-blocking ambiguity and the baseline specs pass.

## Slice 1 — Salary/OTHER built-ins and data reconciliation

Status: salary/OTHER built-ins and the first hierarchy exception were implemented and locally verified on 2026-10-15. The existing `SALARY`/`SALARIO` records for users 1 and 4 kept IDs 24 and 105; user 5 received `SALARIO`. All three received `OTHER` and `OTHER INCOME`. Focused category/user/migration/request specs passed (108 examples). On 2026-10-16 the hierarchy exception was extended to `SUBSCRIPTION` and `SALARY`/`SALARIO` after the main/additional-category clarification; the focused category model/request suite passed (71 examples). This is not a claim about HMG/PROD data.

- Add `salary` and `salario` built-in category translations in en and pt-BR; verify `Category#name` displays either stored key in the active locale. Add salary to the normal built-in category presentation (including colour/icon conventions where relevant).
- Backfill existing users safely: mark their existing `SALARY` or `SALARIO` category built-in in place; create the locale-appropriate one only when neither exists. Preserve IDs, category transaction joins, colours and other metadata. Handle a user with both names explicitly rather than silently merging.
- In the current three-user development data, this means: first user's `SALARY` becomes built-in, second user's `SALARIO` becomes built-in, and third user gets a new `SALARIO` built-in. Identify users by durable attributes or inspect their existing categories and locale; do not encode `.first/.second/.third` ordering in a migration.
- Add the appropriate built-in for new users through `User#create_built_ins` (English `SALARY`; pt-BR `SALARIO`). Make the reconciliation idempotent and safe across HMG/PROD datasets that may not have exactly three users.
- Add real localized `OTHER` (Expense) and `OTHER INCOME` (Income) built-ins for existing and new users. Reconcile same-name top-level categories in place, preserving any direct allocations. Permit custom children under **all four** subscription-family built-ins (`SUBSCRIPTION`, locale-appropriate salary, `OTHER`, `OTHER INCOME`), but not under unrelated built-ins and never built-in children. The Category form must offer these parents; ordinary NARUTO-01 parent behavior stays unchanged.
- Keep all four parents directly selectable, even when childless, on subscriptions and ordinary transaction forms. Keep parent-subtree filtering so queries on the parent include direct and child allocations. Do not add general income/expense flags to categories.

Acceptance: existing category links are unchanged; no duplicate salary category is created; all three development users have the intended salary category; en/pt-BR display changes with locale while stored names stay stable; repeat run makes no further changes; new users get the right built-ins; all four family parents and their custom children are selectable.

Tests: category/user model specs, data backfill tests for both existing names/missing/both-name cases, translation checks, existing allocation preservation, direct OTHER allocation, permitted OTHER children, forbidden children under other built-ins, childless-parent selection, and parent-subtree filters.

## Slice 2 — Kind data and forms

Status: implemented locally on 2026-10-16. The migration backfills existing subscriptions to their user's `SUBSCRIPTION` main category without changing optional additional-category joins. Focused model/request/concern/allocation specs passed (83 examples), Ruby style passed, and the JavaScript bundle built. Manual desktop/PWA interaction and the broader CI suite remain for final verification.

The old single category input is the **additional** category and must remain so. Existing subscriptions with BILL, LEISURE, PRODUCTIVITY, etc. keep those joins; backfill their new main-category FK to built-in `SUBSCRIPTION` without reparenting or rewriting history.

- Add `subscription_kind` with expense default and `main_category_id` FK/backfill. Keep existing category joins as the optional additional category. New records require an owned main category; the form/API accept at most one additional category but do not impose income/expense rules on it. Audit and rollback must capture main-category changes.
- Add a localized main-category selector grouped into SUBSCRIPTION (Expense), SALARY (Income), OTHER (Expense), OTHER (Income). Each group offers its parent and current custom children; child options appear automatically as users create them. The selected main category and kind must be saved and validated together. Show main and additional categories distinctly on desktop/PWA index and show.
- Make new linked transaction defaults match kind: positive cash for income, negative cash/card for expense. Income is cash-only: hide card creation and reject card-linked income server-side, including nested attributes and attach flows. Preserve explicit sign changes only if they remain valid for the chosen kind.
- Make the main category replace automatic `SUBSCRIPTION` tagging on linked transactions; attach the selected **child only** if a child is chosen, plus the optional additional category. A same-kind switch (for example, OTHER → Rent or SUBSCRIPTION → SUBSCRIPTION/Leisure) updates only the managed main allocation through the audited sync path and leaves the additional allocation in place. Update `HasSubscription` and `AllocationMutations::FormCoordinator` to recognize the actual main category rather than hard-coded `SUBSCRIPTION`.
- Block changing kind after creation, even with no linked transactions; reject cross-kind category choices. Keep the derived `price` signed. Never rewrite existing linked prices as an incidental result of a form edit.

Acceptance: all four main families are displayed and localized; newly added children appear in the correct path; every parent is directly selectable; Netflix-style main SUBSCRIPTION plus additional LEISURE is preserved; a child chosen as main is attached without its parent; new income cash works; income card entries fail server-side; persisted kind changes fail; same-kind main changes update linked allocations without changing prices or the additional category; en/pt-BR and desktop/PWA are covered.

Tests: migration/model, request create/update/authorization, immutable kind, main-category family and ownership, additional-category independence, linked cash/card transaction and installment specs, attach-flow rejection for income cards, same-kind main-category replacement and rollback, feature flow for all four options and dynamic children, monthly-analysis regression for positive/negative installment classification.

## Slice 3 — Bulk edit server contract

Status: implemented locally on 2026-10-16. The collection endpoint accepts only explicit IDs (maximum 100) and allowlisted status/additional-category/entity actions. It loads through the current context, locks the selected rows, uses the lifecycle transition for status, and mutates allocations through the subscription model in one transaction and one request audit operation. The linked-allocation regression test exposed and fixed a pre-existing empty-to-populated association sync gap. Focused request and subscription specs passed; the index controls and full rollback verification remain in Slices 4–5.

- Add a strict endpoint and mutation service for explicit selected IDs, one allowlisted action/value, context/owner validation, and an upper selection bound.
- Use one database transaction and the request's existing audit operation. For status, reuse `Logic::Subscriptions::LifecycleTransition` or an equivalent validated shared transition path. For allocations, use the same safe model/association mutation path as single edits.
- Reject the entire set if one row is invalid, stale, foreign, or conflicts with linked financial history. Additional-category/entity actions replace allocations; clearing either is an explicit action. Additional category may be any owned category and must not change main category or kind. Return localized actionable errors.
- Tag the operation with scalar metadata if useful; do not invent an `operation_kind` column.

Acceptance: a successful batch creates one operation with versions for all changed rows; one invalid row causes zero changes; other-context and foreign IDs are never mutated; no-op and duplicate-ID requests behave predictably; linked transaction allocations and audit versions stay consistent.

Tests: request/service specs for all actions, authorization, atomicity, mixed-state rejection, empty/oversized selection, explicit clear and replacement semantics, unrestricted additional category, unchanged main category/kind, and linked cash/card allocation effects.

## Slice 4 — Desktop/PWA bulk controls

Status: implemented locally on 2026-10-16. Desktop rows and mobile cards have explicit selection checkboxes tied to a single localized action bar. Selection clears with filters/navigation because it is held only in the current rendered index; the submission carries the filtered return path. Request specs cover both user-agent layouts and the return destination; a browser feature spec covers selection, apply, and clear at desktop/narrow widths. Manual PWA and light/dark review remain in final verification.

- Add selection controls and a localized action bar to both subscription index presentations. Give mobile cards usable selection affordances without obscuring existing edit links.
- Maintain selection through ordinary index interaction only as far as it remains visible and explicit; clear it on filter/context changes rather than accidentally acting on hidden rows.
- Keep the user's index destination and filters after success/failure. Use normal Turbo navigation first; add stream-based row replacement only if behavior is equivalent and tested for both layouts.

Acceptance: one and multiple selection, cancel/clear, filter change, keyboard access, mobile touch, light/dark mode, and localized errors work without affecting non-selected records.

Tests: feature coverage for desktop and mobile layouts, plus request coverage for redirects or Turbo responses.

## Slice 5 — Rollback hardening

Status: implemented locally on 2026-10-16. Rollback specs now cover income create/destroy, a main plus additional category switch with linked cash allocations, a two-subscription bulk operation, and a later-mutation conflict. Replacing category/entity through associations now destroys the old audited join rather than silently deleting it, and subscription scalar rollback bypasses ordinary linked-sync callbacks because the operation restores its audited dependencies explicitly. The focused subscription, allocation, and rollback suite passed (101 examples). The full CI fast suite passed (2,312 examples); CI overall failed on one cash-navigation feature example that passed when rerun alone. Manual review remains.

- Extend `spec/services/audit/rollback/subscription_adapter_spec.rb` for kind, create, update, destroy, allocation sync, and operation-level bulk rollback.
- Fix adapter/dependency/recalculation gaps discovered by those tests without weakening preview checks.
- Verify an intervening mutation, linked later dependency, or paid-history conflict prevents partial restoration.

Acceptance: bulk apply restores all affected records and dependencies atomically when previewable; conflicts are explicit; derived totals are recomputed rather than restored from stale snapshots.

## Final verification and manual test

- Run focused model, request, service, and feature specs; `bin/rubocop -A`; relevant JS build. Then run `bin/ci` before merge.
- Manually create subscriptions through all four choices, create an OTHER child and confirm it appears, add a recurring cash row, inspect index/show/monthly analysis, bulk-edit a mix of subscriptions, preview/undo the bulk operation, and verify paid-history protection.
- Record any remaining limitation in this contract and in `SPRINT_5.md`; do not call NARUTO-04 complete on code/specs alone if the manual flows remain untested.
