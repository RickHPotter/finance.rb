# KAKASHI-07 Finance Datetime Control Contract

## Goal

Finish the Jiraiya datetime-input migration by replacing the three remaining visible
raw `datetime-local` controls in finance workflows with
`Views::Shared::DatetimeInput` while preserving every existing transaction,
installment, exchange, and payment behavior.

This is a control consolidation. It must not change financial dates, reference-month
rules, paid-history policy, projection ownership, or submitted parameter shapes.

## Audited Surface Inventory

| Surface | Current control | Required result |
| --- | --- | --- |
| nested cash/card installment | raw `datetime-local` in `Views::Installments::Fields` | compact shared date/time control |
| nested exchange | raw `datetime-local` in `Views::Exchanges::Fields` | compact shared control with standalone/editable and card-bound/read-only modes |
| card pay-in-advance modal | raw `datetime-local` in `Views::CardTransactions::PayInAdvanceModal` | standard shared control with minimum and maximum datetime limits |

`user_card_reference_date` in `Views::CardTransactions::FormControls` is a disabled,
derived transport field rather than a visible user control. It remains outside this
migration.

## Canonical Value Contract

Each shared control has one canonical hidden input:

- it keeps the original form field name and nested parameter path
- it stores local wall-clock time as `YYYY-MM-DDTHH:MM`
- it carries the existing CSS classes, Stimulus targets, and parent-controller actions
- it is the value submitted by Rails
- it remains enabled in read-only mode
- it is disabled only when the original form field is genuinely disabled

The visible date and time inputs are projections of that canonical value. They must
never introduce alternate parameter names or submit competing date values.

## Shared Component Extensions

### Compact repeated-row mode

Add an explicit compact presentation to `Views::Shared::DatetimeInput` for installment
and exchange cards:

- date and time remain side by side within the repeated row
- control height must remain compatible with the transaction carousel
- icons, weekday copy, and gaps may be reduced, but tap targets and accessible labels
  remain usable
- the full main-form calendar/time-picker layout must not be embedded in every row
- cash and card submission skeletons must match the final repeated-row height

The existing standard and mobile-calendar modes must remain unchanged for current
callers.

### Read-only visible mode

Add a read-only mode distinct from `disabled`:

- visible date/time controls cannot be changed or focused as editable fields
- the canonical hidden input remains enabled and is submitted
- programmatic updates from a card reference still refresh the visible value
- read-only styling is clear in light and dark mode

This mode is required for card-bound exchanges. Standalone exchanges remain editable.
It is also dynamic for installment rows: the existing installment lock button toggles
the shared control between read-only and editable without disabling canonical
submission.

### Minimum and maximum datetime

The component already enforces `max_datetime`. Extend the same contract with:

- `min_datetime`
- a localized minimum-range message
- native date bounds where useful
- exact datetime comparison when the selected date equals a boundary date
- submission prevention while either boundary is invalid

Range validation must use local date/time values and must not compare formatted strings
or UTC-converted timestamps.

### Unique IDs

Every component receives a string ID derived from its nested builder index:

- installment: `installment_date_<form.index>`
- exchange: `exchange_date_<form.index>`
- pay in advance: a modal-specific stable ID

The hidden input, visible date input, visible time input, labels, calendar, and time
picker must all resolve to unique IDs. `NEW_RECORD`/`NEW_NESTED_RECORD` templates must
be replaced by the nested-form controller's unique child index before becoming active
DOM rows.

## Programmatic Synchronization Contract

`reactive_form_controller.js` and `entity_transaction_controller.js` currently write
directly to `.installment_date` and `.exchange_date`. Those classes move to the hidden
canonical inputs, so the shared controller needs an explicit refresh mechanism.

Required behavior:

1. Parent controller writes the canonical hidden value.
2. Parent controller requests a visible refresh through one documented event or
   shared helper.
3. `datetime_input_controller.js` updates date, time, and weekday output without
   re-emitting a parent change loop.
4. User edits commit to the hidden value and emit the existing bubbling input/change
   events exactly once.

Do not rely on a `MutationObserver` for input property changes and do not duplicate
datetime parsing inside the parent controllers.

## Nested Installment Contract

The installment canonical hidden input must retain:

- `.installment_date`
- `data-reactive-form-target="dateInput"`
- the cash paid-state update action
- the exact `cash_installments_attributes` or `card_installments_attributes` field name

The migration must preserve:

- previous/next reference-month actions
- month/year hidden fields and visible month/year label
- source-date schedule regeneration for eligible unpaid rows
- locked-row preservation during source-date changes
- cash `setPaidIfPastCurrentDay` behavior
- card date/user-card refresh submissions
- duplicate and validation-failure values

Installment datetime editability follows the existing row lock:

- a locked row renders date and time as read-only
- unlocking that row immediately makes date and time editable
- relocking it immediately restores read-only mode
- the canonical hidden input remains enabled in both states
- existing sequential lock/unlock behavior across surrounding installments applies to
  datetime controls as well as price controls

## Nested Exchange Contract

The exchange canonical hidden input must retain:

- `.exchange_date`
- `data-entity-transaction-target="dateInput"`
- `change->entity-transaction#updateReferenceMonthYear`
- the exact nested `exchanges_attributes` field name

Standalone exchanges remain editable. Card-bound exchanges use read-only visible mode
but keep the canonical input enabled. Previous/next reference-month actions must:

- continue updating month/year and the visible label
- fetch and apply the selected user-card reference date for card-bound rows
- refresh the shared visible controls after the canonical value changes
- preserve exchange-lock and paid-history behavior

## Pay-In-Advance Contract

The pay-in-advance modal must preserve:

- the current default-date selection
- autofocus on the visible date control
- `min_date` from the previous reference closing date
- `max_date` from the current reference date
- the submitted `card_transaction[date]` parameter
- the current price and context behavior

The payment window becomes one reusable server-owned contract:

- lower boundary: previous reference closing datetime, when present
- upper boundary: current reference datetime, when present
- boundaries are inclusive and compared at minute precision
- a missing boundary leaves only that side unbounded
- the modal and controller use the same calculator; they must not independently
  reproduce reference lookup rules
- an out-of-range request returns a localized `422 Unprocessable Entity`
- rejection creates neither the card advance nor its linked cash transaction

The shared component receives the calculated local datetime boundaries for immediate
feedback. Backend validation remains authoritative for direct or manipulated requests.

## Rerender and Error Contract

On duplicate, Turbo refresh, or failed validation:

- the component renders from the in-memory record value
- date and time retain minute precision
- hidden and visible values agree on first connection
- no stale pending value from the previous component instance survives
- invalid range feedback is localized and does not overwrite the entered value

## Accessibility and Responsive Contract

- every visible date and time control has an accessible name
- read-only state is exposed semantically, not only through colour
- repeated controls do not create duplicate DOM IDs
- keyboard commit and form submission behavior remain available
- compact rows do not overlap price or lock controls at narrow widths
- light and dark modes preserve borders, focus, disabled/read-only contrast, and
  validation feedback

## Non-Goals

- changing installment or exchange scheduling algorithms
- changing paid-history confirmation rules
- changing reference-date derivation
- replacing `RailsDate`
- introducing timezone conversion or seconds
- redesigning nested installment/exchange cards beyond the space needed by the shared
  control
- migrating hidden derived datetime transport fields
