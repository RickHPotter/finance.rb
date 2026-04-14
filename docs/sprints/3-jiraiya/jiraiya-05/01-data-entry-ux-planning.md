# JIRAIYA-05 Data Entry UX Planning

## Goal

Consolidate the transaction-entry experience so it is faster, more consistent, and
less dependent on transitional UI primitives.

This is a frontend/product track, not a continuation of the JIRAIYA-04
financial-safety rollout.

## Entry Criteria

These preconditions are already satisfied in the shipped repo state:

- JIRAIYA-04 safety/runtime normalization is complete.
- canonical shared-return/reference-chain behavior is live.
- Exchange Audit no longer has pending rollout debt by default.
- there is no hidden pre-`PayMultiple` backend slice still blocking this work.

That means `JIRAIYA-05` can start from UX/product goals, not from repair work.

## Current Baseline

### 1. Combobox stack has been consolidated

The app now uses `RubyUI::Combobox` across the migrated entry surfaces.

The `hotwire_combobox` dependency and old `hw-combobox` integration path have been
removed from the shipped stack.

Planned migration style:

- do not replace everything in one go
- first migrate the easy form surfaces where combobox content is not manipulated by
  Stimulus or custom JavaScript
- then migrate the form surfaces that are still deeply coupled to transaction-entry
  Stimulus behavior, especially card/cash transaction entry
- build any missing `RubyUI::Combobox` behavior as the migration exposes it, instead
  of trying to guess the entire missing feature set upfront
- the end result of Slice 2 was the full removal of `hotwire_combobox`
- during migration, prefer making `RubyUI::Combobox` support the minimum behavior
  needed for existing Stimulus controllers to keep working, instead of rewriting all
  dependent JS up front

### 2. Chain creation and duplication are now in place

The repeated-entry workflow is now live across the main in-scope models.

Shipped state:

- `CardTransaction` supports chained create and duplicate flows
- `CashTransaction` now exposes explicit duplication and chained create/duplicate
  flows
- `Investment` now exposes explicit duplication and chained duplicate flow
- the form surface now shows:
  - `Chain Creating`
  - `Chain Duplicating`
- chain controls now include:
  - `Create more` / `Duplicate more`
  - finish while saving the current form
  - finish without saving the current form
- end-of-chain returns to index scoped to the created family

### 3. Date and datetime UX has a first shipped pass

The main transaction forms now use an app-controlled split date/time input instead of
leaning on raw `datetime-local`.

Shipped state:

- `CardTransaction` and `CashTransaction` use the shared split control
- time input is 24-hour friendly and optimized for keyboard entry
- editing only time preserves the current date
- transaction forms now expose an `Esc` quick-jump overlay for fast field-to-field
  keyboard navigation
- desktop flow is faster without jumping to a custom calendar/clock
- mobile/PWA keeps the conservative native date behavior for now

Still intentionally out of scope for this first pass:

- installments
- exchanges

### 4. Bulk selection feedback is now in place

`BulkActionBar` now communicates:

- selected count
- aggregate selected amount
- available actions
- disabled-action reasons when the selection mixes incompatible rows

Shipped behavior:

- all rendered rows are selectable
- the bar stays hidden until a selection exists, then fades away after deselection
- `Select Page` selects every currently rendered row across visible month-year groups
- shift-click range selection works across month-year containers
- pay/transfer disable when the selected cash installment set contains ineligible rows
- `Add to Subscription` is available for cash/card indexes through an existing-subscription modal

### 5. Partial `PayMultiple` was pulled into the slice later

The shipped cash-installment bulk flow now supports both:

- full `PayMultiple`
- partial `PayMultiple`

The partial path is intentionally constrained:

- the entered amount must fully pay all selected installments except one
- the remaining partial installment must be explicitly selected from the valid
  candidates
- the selection becomes invalid again if the amount no longer fits the chosen
  partial target

This keeps the bulk partial-pay behavior deterministic instead of turning it into
free-form allocation.

## Scope

`JIRAIYA-05` should cover:

1. consolidating entry primitives across transaction forms
2. keeping `RubyUI::Combobox` as the single supported combobox primitive in
   user-facing form flows
3. making chain creation / duplication materially faster
4. unifying date/datetime behavior across desktop and mobile
5. making bulk actions more informative before the user confirms them
6. adding the constrained partial `PayMultiple` flow for cash installments

## Non-Goals

For now, `JIRAIYA-05` should not include:

- another exchange/shared-return normalization pass
- category/entity allocation redesign beyond the current hard safety block
- conversation/assistant product work
- a full rewrite of every form/controller in one shot
- another round of partial-payment expansion beyond the current deterministic
  cash-installment flow

## Product Principles

1. The fastest path should also be the safest path.
2. Entry screens should feel consistent across card, cash, and adjacent financial
   models.
3. Mobile behavior should be intentionally supported, not tolerated.
4. New UI work should stay inside the current stack: Phlex, Tailwind, Turbo,
   Stimulus, and `ruby_ui`.
5. `RubyUI::Combobox` should remain the only supported combobox primitive in this
   track.
6. Combobox migration should happen step by step, not through one destabilizing
   rewrite.
7. Date entry should optimize for fast typed input first, not picker-first novelty.

## Remaining Product Decision

1. Partial-payment expansion beyond the current shipped flow
   - current answer: no broader expansion yet
   - if it returns, it should stay tightly scoped to deterministic cases

## Locked Direction For Chain Creation

The current intended scope is:

- support chain creation / duplication for `CardTransaction`
- add explicit duplication for `CashTransaction`
- add explicit duplication for `Investment`
- do not add duplication for `Budget` in this slice
- do not add duplication for `Subscription` in this slice

Behavior target:

1. Clean `new`
   - form starts essentially blank
   - only minimal preserved params survive between chained rounds
   - example: `user_card_id` on card transactions, because card entry requires a
     default card
   - each new round should stay clean as well; round 1 values should not become the
     implicit template for round 2

2. `duplicate`
   - first duplicated form should behave like the current duplicate flow
   - each next round should use the transaction just created as the new sample
   - example:
     - transaction 1 duplicates into transaction 2
     - transaction 2 becomes the sample for transaction 3
   - for cash transactions, mirror current card duplication behavior as closely as
     possible

3. Chain state UI
   - reuse the existing operation label area
   - add:
     - `Chain Creating`
     - `Chain Duplicating`

4. New chain controls
   - a localized checkbox:
     - `Create more`
     - `Duplicate more`
   - a localized button to finish the chain while saving the current form
   - a second localized button to finish the chain without saving the current form

5. End-of-chain landing
   - once the chain finishes, the index should render the transactions created in
     that chain
   - they should be located through the relevant `*_installment_id`
   - default target behavior: land in an index state filtered to the created family
   - visual highlighting can be added later if it helps, but it is not required to
     start the slice

6. Loading feedback
   - optional but recommended in this slice
   - if saving/rendering takes around a second, add skeleton-style loading feedback
   - if implemented well, this should be reusable in other app flows later

## Locked Direction For Date Inputs

The intended direction is conservative:

- do not build a bespoke calendar/clock first
- do not start with a heavy visual date-time picker experiment

Preferred direction:

1. desktop
   - prioritize fast typed entry and faster keyboard navigation
   - move away from slow segmented native datetime interaction
   - accept and normalize 24-hour input consistently inside the app

2. mobile / PWA
   - stay conservative first
   - native pickers can remain the fallback until the desktop input contract is
     clearly better

3. app behavior
   - the app should own parsing and normalization more explicitly
   - browser locale quirks should not be the main UX contract
   - if the user edits only the time portion, the current date should remain as-is

4. shortcut tokens
   - do not commit to tokens like `y`, `o`, `a`, `t`, `d`, `m`, `h` in the first
     pass
   - these can be evaluated later only if the base keyboard flow is still not fast
     enough

This slice should be judged by speed and daily usability, not by how fancy the picker
looks.

Current shipped boundary:

- complete for main card/cash transaction forms and the main pay/transfer modals
- still not extended to installments or exchange-specific forms

## Locked Direction For Bulk Action Bar

The shipped direction is:

1. add aggregate information directly in the bar
   - first target: aggregated selected price

2. allow all transactions to be selectable
   - action availability should be computed from the selection
   - pay/transfer must disable when the current selection contains rows that cannot
     perform that action

3. improve selection mechanics
   - support shift-click range selection
   - add a bar-level `Select all` action
   - this `Select all` should cover every currently rendered row across all visible
     month-year groups, not only one month-year group
   - avoid duplicating that control in the filter area

4. add `Add to Subscription` as a bulk action for card and cash indexes
   - not every selected row type should be eligible
   - obvious ineligible cash examples today:
     - `CARD PAYMENT`
     - `CARD ADVANCE`
     - `INVESTMENT`
   - card transactions are the more natural first-class candidates
   - clicking the action should open a modal to choose an existing subscription and
     confirm the attachment
   - the write attaches selected transaction records, not installment ids
   - attachment syncs subscription metadata into the transaction:
     - sets `subscription`
     - syncs description/comment
     - merges the transaction categories with the subscription categories and
       `SUBSCRIPTION`
     - merges existing transaction entities with the subscription entities
   - no background job is required for the base version

5. action feedback
   - invalid actions should stay visible but disabled
   - the bar should explain why an action is disabled, either inline or through a
     tooltip/hover message

6. subscription allocation safety
   - transactions in the subscription flow may change category/entity allocation even
     after paid history exists
   - this bypass is intentionally narrow and depends on the transaction having
     `SUBSCRIPTION` in either its original or current category set

## Validation Rule

For this track, prefer:

- manual pass on the real affected flows after each slice
- request specs only when they protect behavior that is easy to regress and hard to
  eyeball

Do not add feature specs for this work.

## Recommendation

Start `JIRAIYA-05` with the transaction-entry stack only:

- card transactions
- cash transactions
- investments
- bulk payment UX

That is enough surface area to establish the new primitives without exploding the
scope too early.
