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

### 2. Chain creation and duplication are still underpowered

There is a real duplicate flow for `CardTransaction`, but the broader “finish this
entry and immediately continue with the next similar one” workflow is still weak.

Current limitations:

- duplicate is card-first, not a unified transaction-entry workflow
- `CashTransaction` does not expose explicit duplication yet
- `Investment` has an implicit “next day” style helper path, but not an explicit
  duplicate flow
- there is no explicit chained “create more / duplicate more” flow
- the post-save experience still assumes the user is done after one creation

### 3. Date and datetime UX is inconsistent

Current entry surfaces use a mix of:

- `datetime-local` on cash/card transaction forms
- `datetime-local` on bulk payment modal
- `date` on investments

Known pain points:

- mobile/PWA datetime pickers are awkward
- keyboard-first editing is uneven
- there is no single app-level contract for “date only” vs “date and time”
- browser-native segmented datetime entry is too slow for fast keyboard usage
- locale/browser formatting rules are doing too much work for the user instead of the
  app
- 12-hour browser presentation plus permissive 24-hour parsing creates inconsistent
  expectations

### 4. Bulk selection feedback is minimal

`BulkActionBar` currently communicates:

- selected count
- available actions

It does not communicate:

- aggregate selected amount
- selection type/constraints
- whether the current selection mixes incompatible rows
- page-level selection across all visible month groups
- range selection through shift-click
- subscription conversion as a bulk action

### 5. Partial `PayMultiple` is still intentionally out

The shipped `pay_multiple` flow bulk-pays full installments only.

That is the current product decision, not an incomplete hidden rollout.

If partial `PayMultiple` returns, it should be treated as a later `JIRAIYA-05`
decision gate, not as an assumed requirement of the base consolidation work.

## Scope

`JIRAIYA-05` should cover:

1. consolidating entry primitives across transaction forms
2. keeping `RubyUI::Combobox` as the single supported combobox primitive in
   user-facing form flows
3. making chain creation / duplication materially faster
4. unifying date/datetime behavior across desktop and mobile
5. making bulk actions more informative before the user confirms them

## Non-Goals

For now, `JIRAIYA-05` should not include:

- another exchange/shared-return normalization pass
- category/entity allocation redesign beyond the current hard safety block
- conversation/assistant product work
- a full rewrite of every form/controller in one shot
- partial `PayMultiple` unless it is deliberately pulled in later

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

## Open Decisions Before Implementation

These are product choices to settle early:

1. Does partial `PayMultiple` enter this sprint at all?
   - default answer today: no
   - if yes, it should be a late, gated slice

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
   - a localized button to finish the chain immediately
   - that finish button should behave the same as unchecking the checkbox and saving

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

## Locked Direction For Bulk Action Bar

The intended direction is:

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
   - the write should directly update `subscription_id` on the selected eligible
     records
   - no background job is required for the base version if the action remains a
     direct update

5. action feedback
   - invalid actions should stay visible but disabled
   - the bar should explain why an action is disabled, either inline or through a
     tooltip/hover message

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
