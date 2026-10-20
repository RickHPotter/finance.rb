# NARUTO-05 — Implementation slices and acceptance matrix

The product decisions are locked in the [product contract](01-product-and-data-contract.md). Complete, verify, and commit one slice at a time. This plan is not an implementation status report.

## Slice 0 — Baseline and dependency map

- Capture existing credit behavior: card creation, date/card changes, billing `Reference`, installment schedule, invoice cash projection, paid/unpaid actions, credit card show/index, report totals, and audit rollback.
- Trace direct and indirect reference consumers: `UserCard#find_or_create_reference_for`/`#calculate_reference_date`, `CardTransaction#build_month_year`/`#card_payment_date`, `CardInstallment#card_payment_date`, `CashTransactable` callbacks, `UserCardsController#reference_date`, card transaction and card forms, subscriptions, exchange/card-bound flows, imports, context cloning, balance recalculation, reports, and rollback.
- Verify the locked paid-state behavior against the baseline: future-dated noncredit purchases start unpaid and stay that way until the user confirms payment; today/past purchases use the existing date-based default. `min_spend` is credit-only and nil for noncredit cards.

Done when the baseline specs pass and every creation path is inventoried.

## Slice 1 — Card kinds and safe schema

- Add the string-backed `card_kind` enum, database default `credit`, value constraint, and nullable owned bank-account FK. Make credit-only fields, including `min_spend`, nullable for noncredit cards.
- Conditional model validation for credit cycle/limit fields, required owned bank account for debit, and blank association for other kinds. Make `card_kind` immutable after any transaction or reference exists in any context. Keep unused-card edits possible. Avoid a model callback that silently deletes dependency records.
- Ensure existing cards remain `credit` and their financial fields and links are unchanged. Include migration checks and rollback-safe behavior for a missing or foreign bank account.

Acceptance: old rows are unchanged except `card_kind=credit`; new prepaid/debit cards can omit irrelevant fields; credit cannot omit required fields; invalid kind, foreign account, stale association, and used-card conversion fail both model and request validation.

Tests: migration and `UserCard` model/request specs, including an existing-card fixture, multiple contexts, direct parameter tampering, and unused-card kind changes.

## Slice 2 — Noncredit transaction engine

- Branch transaction period calculation: credit uses reference month/year; prepaid/debit use purchase month/year. Guard every direct reference helper call and the direct reference-date endpoint. Preserve existing credit date/billing calculations.
- Keep one `CardInstallment` for each noncredit purchase. Future-dated purchases start unpaid and require explicit confirmation later; today/past purchases use the existing date-based default. Reject additional nested installments on create/update; do not rely on the form count. Ensure noncredit installments skip `CashTransactable` projection callbacks and keep `cash_transaction_id` null. Do not delete credit projections.
- Revisit card-switch, duplicate, subscription, advance, split-purchase, fiscal import/draft, exchange/card-bound, context-clone, import, and background paths. Where conversion would corrupt linked history, return a clear validation error rather than partially changing records. Recalculate only the totals that apply to noncredit card spending.
- Decide and encode how noncredit purchases participate in month/year and category/entity searches without being counted as invoices. Prevent bank-balance mutation or double counting in V1.

Acceptance: create/edit/delete a noncredit purchase leaves zero References and zero invoice cash projections; one installment has the intended purchase month/year/date/paid state; a future planned purchase remains unpaid after its date passes until explicitly confirmed; same credit scenarios keep producing their established references/projections; failures are atomic.

Tests: model, request, and service specs for each kind, direct endpoint abuse, 2-installment payload rejection, cross-kind card switching, date changes, duplicate, split purchase, subscription attachment, fiscal import, exchanges, and credit regressions.

## Slice 3 — Card and purchase UI

- Localize kind names and validation messages. Add responsive kind selector and conditional credit/debit fields to card new/edit; keep the new form's default `credit`. Show kind on card index/show; show bank-account association only for debit and a clear spending-only notice for prepaid.
- Make card transaction new/edit react when card kind/date changes. Noncredit gets a single-installment presentation and purchase period; no billing reference/closing date controls or invisible refresh that calls the reference endpoint. Credit layout and behavior must remain intact.
- Disable or omit credit-only reference, invoice, limit, and payment actions for noncredit on desktop/PWA; reject direct requests too. Keep index filters, return paths, and keyboard/touch interaction intact.

Acceptance: all three kinds can be created from desktop/PWA; invalid fields are explained in the active locale; noncredit edit never displays a fictional bill; credit screens are visually and functionally unchanged.

Tests: feature/request coverage of both layouts, kind switching before save, bank-account selection, one installment, no reference request, localization, and credit UI regression.

## Slice 4 — Read models, financial safety, and rollback

- Review user-card totals, card transaction indexes, monthly analysis, charts, reports, filters, search, unpaid-invoice queries, payment actions, and NARUTO-06 input assumptions. Explicitly distinguish recorded prepaid/debit spending from prepaid remaining value or a bank balance. Credit available-limit calculations must filter to credit cards.
- Extend audit/rollback adapter dependency and preview tests for card kind and bank-account changes, transaction create/update/destroy, and noncredit installment history. Recheck paid-history protection and operation atomicity. Ensure undo of noncredit operations cannot reintroduce a Reference or invoice projection.
- Reconcile old contexts/credit data without rewriting it; document any unsupported legacy combination and migration remediation before shipping.

Acceptance: no double count between card spending, invoice cash, and bank balances; card-kind scope is visible in financial summaries; credit history is unchanged; rollback previews are accurate and conflicts prevent partial restoration.

Tests: query/service/report specs, audit adapter specs, cross-context and paid-history cases, NARUTO-06-facing aggregate regression checks.

## Slice 5 — Final verification and manual handoff

- Run focused specs, relevant feature specs, `yarn build`, `bin/rubocop -A`, and `bin/ci` according to repository instructions. Fix failures or record genuine external CI blockers without calling the feature tested.
- Manually create credit, VA/VR prepaid, and debit cards; record a purchase; change date/card and inspect month/year; verify exactly one installment and no noncredit reference/invoice cash row; test direct reference route, invalid/foreign bank account, both locales, PWA, index/report totals, and rollback. Verify old credit card billing and payment again.
- Record manual evidence, outstanding limitations, and NARUTO-06 follow-up in this document and `SPRINT_5.md`. Do not claim HMG/PROD validation from local testing.

Ready for manual testing means Slices 1–4 and automated checks are complete. Done means manual acceptance passes and the remaining follow-on work is explicitly separate.
