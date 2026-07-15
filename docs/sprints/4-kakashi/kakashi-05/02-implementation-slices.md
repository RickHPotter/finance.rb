# KAKASHI-05 Piggy Bank Transaction Flow: Implementation Plan

## Delivery Strategy

Implement the flow in vertical slices. Each slice should leave model invariants valid
and focused specs passing. Avoid extending `ExchangeCashTransactable`; extract only a
small shared projection helper if concrete duplication appears during implementation.

## Slice 1: Lock Product Decisions and Category Contract

1. Resolve the decisions in `03-decisions-and-test-matrix.md`.
2. Add constants for the exchange and piggy-bank category families in one domain
   module rather than repeating string arrays.
3. Add model validation that rejects mixed families and same-family source/return
   combinations.
4. Add English and Portuguese error translations.
5. Add cash transaction specs for mixed families and card transaction specs proving
   that piggy-bank categories are rejected entirely.

Primary touchpoints:

- `app/models/concerns/category_transactable.rb` or a new focused concern
- `app/models/cash_transaction.rb`
- `app/models/card_transaction.rb`
- `config/locales/models/categories.yml`
- `spec/models/cash_transaction_spec.rb`
- `spec/models/card_transaction_spec.rb`

Acceptance criteria:

- invalid combinations fail without creating or changing any transaction
- validation works for persisted and in-memory nested categories
- exchange behavior remains unchanged

## Slice 2: Built-in Categories and Data Migration

1. Add `PIGGY BANK` and `PIGGY BANK RETURN` to new-user built-ins.
2. Backfill both built-ins for every existing user with idempotent migration code.
3. Add localized category names.
4. Keep `PIGGY BANK` available in the category selector and hide
   `PIGGY BANK RETURN` from normal source entry.
5. Leave all existing `INVESTMENT` rows and behavior unchanged.

Primary touchpoints:

- `app/models/user.rb`
- `app/models/concerns/category_transactable.rb`
- `config/locales/models/categories.yml`
- a new data migration
- `spec/models/user_spec.rb`

Migration requirements:

- use `find_or_create_by!` semantics scoped by user and category name
- force `built_in: true` for canonical categories
- remain safe when rerun or when a user already has a same-named category
- do not rename, classify, or link existing `INVESTMENT` rows

## Slice 3: Piggy Bank Link Model

1. Create the `piggy_banks` table and model described in the domain design.
2. Add explicit source and return `CashTransaction` associations. Keep source ownership
   unique, but allow several contribution links to share one return.
3. Add nested input support from the source transaction form.
4. Validate user/context/category consistency and exactly one active source entity.
   Do not validate that the entity is a bank.
5. Validate a strictly negative source price and a strictly positive return price.
6. Define explicit pending/finished helpers from the linked return paid state.
7. Add factories and model specs before projection callbacks are introduced.

Primary touchpoints:

- new migration and `app/models/piggy_bank.rb`
- `app/models/entity_transaction.rb`
- `app/models/cash_transaction.rb`
- `spec/factories/piggy_banks.rb`
- `spec/models/piggy_bank_spec.rb`
- `spec/models/entity_transaction_spec.rb`

Acceptance criteria:

- one source cash transaction cannot own multiple piggy-bank links
- one source cannot own multiple piggy-bank links
- one eligible return may belong to multiple piggy-bank contribution links
- cross-user or cross-context links are invalid
- a source with zero or multiple active entities is invalid
- zero/positive source prices and zero/negative return prices are invalid
- direct association destruction cannot orphan a return silently

## Slice 4: Atomic Return Projection

1. Add a focused concern/service that creates and synchronizes the generated return.
2. Build a new return `CashTransaction`, or attach to an eligible open return group,
   with:
   - source description
   - source user and context
   - `cash_transaction_type: "PiggyBank"` or another locked discriminator
   - `PIGGY BANK RETURN`
   - the same entity as a non-paying entity allocation
   - the source `user_bank_account_id`
   - one initial installment matching return date and price
   - grouped source navigation through `PiggyBank` links rather than one authoritative
     `reference_transactable`
3. Synchronize unpaid return date, grouped principal, recognized profit, description,
   entity, and the initial installment only before payment history exists.
   For partially paid groups, preserve paid installments and apply later contributions
   or profit/loss deltas to the unpaid remainder instead of rebuilding history.
4. Destroy an unpaid projection when its final contribution link is removed. Removing
   one of several links only reduces the grouped principal.
5. Protect paid projections using existing safety-rule conventions.
6. Preserve the installment structure created by `CashInstallmentsController#pay`
   after a partial payment; projection sync must not rebuild it from `return_price`.
7. Enforce positive prices on every return installment produced by initial projection
   or partial-payment splitting.
8. Wrap source/link/return mutations in the transaction save boundary so partial
   projection creation cannot persist.

Primary touchpoints:

- new piggy-bank projection concern/service
- `app/models/piggy_bank.rb`
- `app/models/cash_transaction.rb`
- `app/models/concerns/has_financial_safety_guards.rb`
- localized validation/history errors
- new concern/service specs

Acceptance criteria:

- creating a source creates exactly one linked return
- updating an unpaid link cannot produce duplicate returns or installments
- validation failure rolls back source and projection together
- paid history cannot be silently rewritten or deleted
- a partial payment splits the initial installment and preserves the unpaid remainder
- later source saves do not collapse partially paid return installments
- invalid signs produce localized errors and roll back the whole operation

## Slice 5: Controller and Duplication Boundaries

1. Permit `piggy_bank_attributes` for cash transactions only.
2. Sanitize/deduplicate nested entity payloads without dropping piggy-bank fields.
3. Decide duplication behavior explicitly. Recommended behavior:
   - duplicate the source category and entity
   - duplicate return date/value as editable nested input
   - default to a new return and never copy paid state
   - allow explicit selection of another eligible future return
4. Exclude system-generated returns from bulk subscription and transfer actions.
5. Add request specs for create, update, invalid combinations, rollback, duplication,
   and unauthorized/cross-context identifiers.

Primary touchpoints:

- `app/controllers/cash_transactions_controller.rb`
- the card controller's category rejection path
- transaction duplication methods
- cash transaction request specs and a focused card rejection spec

## Slice 6: Category-Aware Entity Sheet

1. Pass canonical piggy-bank category identifiers into the cash transaction form, following
   the existing exchange-category hidden metadata pattern.
2. Teach `reactive_form_controller.js` to expose category-family state as a form-level
   value/event.
3. Render separate exchange and piggy-bank bodies inside the entity sheet.
4. In piggy-bank mode render only:
   - selected entity context
   - create-new-return or attach-to-existing-return mode
   - an eligible return selector filtered to the selected bank entity
   - return date via `Views::Shared::DatetimeInput`
   - return price via the existing price-mask control
5. Default return price to the opposite of transaction price only for a new/unmodified
   piggy-bank input.
6. When attaching to an existing return, display its original date as disabled and do
   not submit a replacement date.
7. Keep the source price mask negative and the return price mask positive in this mode;
   model validation remains authoritative for forged payloads.
8. Re-evaluate every open entity sheet when categories change.
9. Hide incompatible category options proactively, while preserving server validation.
10. Align any loading skeleton with the real mobile date/price controls.

Primary touchpoints:

- `app/views/cash_transactions/form.rb`
- `app/views/entity_transactions/fields.rb`
- `app/views/entity_transactions/fields_sheet.rb`
- a new piggy-bank fields component
- `app/javascript/controllers/reactive_form_controller.js`
- `app/javascript/controllers/entity_transaction_controller.js` or a new focused
  `piggy_bank_controller.js`
- `app/javascript/controllers/index.js`

Acceptance criteria:

- normal entity sheets are visually and behaviorally unchanged
- selecting `PIGGY BANK` switches all eligible entity sheets to the compact mode
- removing it restores exchange mode without stale active piggy-bank input
- customized return price is not overwritten by unrelated form changes
- exact DOM IDs use strings where Stimulus or tests depend on them
- desktop and mobile layouts contain no overlapping or clipped controls
- attaching to an existing return keeps the compact sheet and does not expose exchange
  installment scheduling

## Slice 7: Read Surfaces and Lifecycle Actions

1. Show contribution/group linkage on cash detail screens and index rows where useful.
2. Display the expected return date, original principal, paid amount, and remaining
   amount using the return transaction's installments.
3. Provide navigation from every source to its return and from the return to all sources.
4. Add a `PIGGY BANK RETURN#edit` list sheet analogous to `EXCHANGE RETURN`, listing
   all contributing source transactions and their principal amounts.
5. Mark generated returns as system-managed and route source-level changes through the
   corresponding source flow while keeping grouped fields authoritative.
6. Update `can_be_updated?`, `can_be_deleted?`, bulk eligibility, and search/filter
   behavior for both categories.
7. Add category filters without conflating these rows with the existing `Investment`
   aggregate transaction type.

Primary touchpoints:

- cash show and index Phlex views
- `app/models/cash_transaction.rb`
- search forms/controllers
- request and view/feature coverage used by the repository

## Slice 8: Investment Valuation Integration

1. Add an explicit association from a supported `Investment` valuation/profit record
   to a piggy-bank return group.
2. Let `/investments` select the target return group through a description-based
   searchable selector. Descriptions distinguish multiple piggy banks at one bank.
3. Keep a group selectable until all linked source transactions and every return
   installment are paid.
4. Record daily, monthly, or ad hoc signed profit/loss deltas:
   - positive `Investment#price` means profit
   - negative `Investment#price` means loss
   - negative prices remain invalid for ordinary, non-piggy-bank investments
5. Recalculate the grouped return as:
   - sum of linked projected principal
   - plus the sum of linked signed investment deltas
6. For the baseline case, a principal of `800` plus recognized profit of `8` updates
   the return cash transaction and its initial installment to `808`.
7. Preserve paid installments when later contributions or deltas change a partially
   paid group; update only the unpaid remainder.
8. Reject a loss or recalculation that would make the grouped return or an unpaid
   remainder zero or negative.
9. Preserve attribution per return group so amalgamated withdrawals do not erase the
   profitability of separate investments.
10. Do not automatically migrate or reinterpret existing legacy `INVESTMENT` rows.

Primary touchpoints require a separate audit of the current `Investment` model,
`/investments` forms, and investment projection callbacks before implementation.

## Slice 9: Operational Audit

1. Add an admin audit for broken piggy-bank links:
   - missing return
   - wrong category
   - user/context/entity mismatch
   - duplicate contribution ownership for one source
   - incompatible sources sharing a grouped return
   - grouped principal drift
   - valuation/profit drift
   - source/return amount drift before payment
   - illegal installment collapse after partial payment
2. Add a repair runner only after the audit output is stable and tested.

Existing `INVESTMENT` rows must not be included in the audit or repair runner.

## Verification Per Slice

After each edit batch:

1. Run `bin/rubocop -A`.
2. Load `.env.test`, falling back to `.env`.
3. Run focused RSpec files with elevated PostgreSQL access.
4. Run the model/concern/request CI subset after backend slices.
5. Run `yarn build` after Stimulus changes.
6. For UI slices, start `bin/dev` and verify desktop and mobile flows with screenshots.

Before merging the complete feature, run `bin/ci` and perform a migration dry run on a
recent production-like database copy.

## Suggested Commit Boundaries

1. `feat: add piggy bank category safeguards`
2. `feat: add piggy bank built-in categories`
3. `feat: model piggy bank return links`
4. `feat: project piggy bank cash returns`
5. `feat: add piggy bank entity sheet`
6. `feat: expose grouped piggy bank lifecycle`
7. `feat: link investment valuation to piggy bank returns`
8. `app: audit piggy bank projections`
