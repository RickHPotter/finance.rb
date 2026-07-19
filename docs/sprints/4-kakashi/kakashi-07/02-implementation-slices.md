# KAKASHI-07 Implementation Slices

## Delivery Strategy

Implement the shared contract first, then migrate one consumer family at a time. Each
slice must leave cash/card forms usable and must preserve the canonical hidden input
expected by existing parent Stimulus controllers.

## Slice 1: Extend the shared datetime control

1. Add compact and read-only options to `Views::Shared::DatetimeInput`.
2. Add `min_datetime` and localized minimum-range feedback alongside the existing
   maximum contract.
3. Apply date portions of minimum/maximum values to the visible date input.
4. Keep exact boundary comparisons in `datetime_input_controller.js`.
5. Add a documented event/method for refreshing visible controls after a parent
   controller changes the canonical hidden value.
6. Add a documented dynamic read-only transition used by installment locking.
7. Ensure refresh and mode changes do not emit recursive input/change events.
8. Keep current standard and calendar callers backward compatible.

Primary touchpoints:

- `app/views/shared/datetime_input.rb`
- `app/javascript/controllers/datetime_input_controller.js`
- `config/locales/locale.yml`
- focused request/component coverage for existing callers

Acceptance criteria:

- standard and calendar modes render unchanged
- compact mode has stable repeated-row dimensions
- read-only visible controls submit the canonical hidden value
- minimum and maximum boundaries reject only out-of-range values
- parent-driven canonical changes refresh date, time, and weekday output
- dynamic read-only transitions preserve the canonical value and submission state

## Slice 2: Migrate nested installments

1. Replace the raw field in `Views::Installments::Fields`.
2. Generate a string ID from `form.index`.
3. Put `.installment_date`, the `reactive-form` date target, and the cash paid-state
   action on the canonical hidden input.
4. Use compact presentation for both cash and card rows.
5. Update `reactive_form_controller.js` to refresh visible controls after every direct
   installment-date write.
6. Update `installment_lock_controller.js` so every row lock/unlock transition also
   updates datetime read-only state.
7. Preserve locked installments when the source transaction date changes.
8. Align both cash and card submission skeletons with the compact row.

Primary touchpoints:

- `app/views/installments/fields.rb`
- `app/javascript/controllers/reactive_form_controller.js`
- `app/views/cash_transactions/form_submission_skeleton.rb`
- `app/views/card_transactions/form_submission_skeleton.rb`
- `spec/requests/cash_transactions_spec.rb`
- `spec/requests/card_transactions_spec.rb`

Acceptance criteria:

- no visible raw `datetime-local` installment field remains
- nested cash/card dates persist with minute precision
- month/year labels and hidden fields remain synchronized
- source-date changes update only eligible rows
- cash automatic paid-state behavior remains correct
- locked rows have read-only date/time controls and unlocked rows are editable
- duplicate and failed-validation forms retain entered values

## Slice 3: Migrate nested exchanges

1. Replace the raw field in `Views::Exchanges::Fields`.
2. Generate a string ID from the nested exchange builder index.
3. Preserve `.exchange_date`, the entity target, and the month/year action on the
   canonical hidden input.
4. Use compact editable mode for standalone rows.
5. Use compact read-only mode for card-bound rows while keeping hidden submission
   enabled.
6. Update every direct exchange-date write in
   `entity_transaction_controller.js` to refresh the visible control.
7. Preserve previous/next month, reference fetch, lock, paid-history, add/remove, and
   count-regeneration behavior.

Primary touchpoints:

- `app/views/exchanges/fields.rb`
- `app/javascript/controllers/entity_transaction_controller.js`
- `spec/requests/cash_transactions_spec.rb`
- `spec/requests/card_transactions_spec.rb`
- `spec/concerns/exchange_cash_transactable_spec.rb`

Acceptance criteria:

- standalone exchanges remain editable
- date edits update exchange month/year once
- card-bound rows cannot be manually edited
- card-bound reference changes update hidden and visible values together
- every active repeated row has unique IDs
- locked or paid histories still reject unsafe structural rewrites

## Slice 4: Migrate card pay in advance

1. Extract one payment-window calculator from the current previous/current reference
   lookup.
2. Use that calculator from both card transaction detail rendering and
   `CardTransactionsController#pay_in_advance`.
3. Reject out-of-range requests with localized feedback, `422`, and no persisted card
   or cash transaction.
4. Replace the modal's raw field with the standard shared control.
5. Pass the calculated minimum and maximum local datetimes.
6. Keep the current default date calculation.
7. Move autofocus expectations to the visible date input.
8. Add render coverage for IDs, hidden canonical value, visible values, autofocus, and
   range configuration.
9. Keep pay-in-advance request coverage for creation, linked cash projection, and
   context isolation.

Primary touchpoints:

- `app/views/card_transactions/pay_in_advance_modal.rb`
- `app/views/card_transactions/show.rb`
- the shared payment-window model/service selected during implementation
- `app/controllers/card_transactions_controller.rb`
- `spec/requests/card_transactions_spec.rb`

Acceptance criteria:

- the modal contains no visible raw `datetime-local` field
- the earliest and latest permitted moments remain unchanged
- the visible date receives autofocus
- a valid submitted datetime creates the same card/cash records as before
- a direct request outside the window returns `422` and creates no records

## Slice 5: Regression and manual verification

1. Search for remaining visible raw `datetime-local` finance controls and classify any
   intentional hidden transport field.
2. Run `node --check`, `yarn build`, and RuboCop after the final JavaScript/Ruby batch.
3. Run focused cash transaction, card transaction, cash installment, exchange concern,
   and reference specs.
4. Run `spec/models`, `spec/concerns`, and `spec/requests` before merge.
5. Manually exercise new/edit/duplicate/failure flows on desktop and mobile.
6. Check standalone and card-bound exchanges with previous/next actions.
7. Check pay in advance exactly at minimum and maximum boundaries and immediately
   outside them through both the UI and direct requests.
8. Verify light/dark, keyboard, read-only, validation, and narrow carousel states.

Acceptance criteria:

- no duplicate IDs or overlapping repeated-row controls
- hidden and visible datetime values never disagree after user or programmatic changes
- no changed financial parameter names or month/year behavior
- no regression in paid-history guards or generated projections

## Suggested Commit Boundaries

1. `feat: extend shared datetime control contracts`
2. `feat: migrate nested installment datetime controls`
3. `feat: migrate nested exchange datetime controls`
4. `feat: migrate and validate card advance payment datetime`
5. `spec: harden finance datetime control behavior`
