# KAKASHI-07 Decisions and Test Matrix

## Locked Decisions

### D1. What value is authoritative?

The hidden `YYYY-MM-DDTHH:MM` input is canonical. Visible date/time controls only edit
or display that value. Rails parameter names remain unchanged.

### D2. Where do existing Stimulus contracts live?

Existing parent targets, semantic classes, and parent actions remain on the canonical
hidden input. Visible controls carry only shared datetime behavior and presentation.

### D3. How do parent controllers update the shared control?

They write the canonical value and invoke one explicit shared refresh contract. They
must not reproduce parsing, time normalization, weekday formatting, or range logic.

### D4. How does read-only differ from disabled?

Read-only prevents visible editing but submits the canonical hidden value. Disabled
disables canonical submission as well. Card-bound exchanges use read-only, not
disabled.

### D5. How are transfer/card reference dates handled?

Reference ownership is unchanged. Card-bound exchange dates continue to derive from
the selected `UserCardReference`; the shared input only renders and submits that
derived local value.

### D6. Which modes use the large mobile calendar/clock?

Main transaction forms keep their existing calendar mode. Repeated installment and
exchange rows use the compact split control so a carousel row does not contain an
expanded calendar and time picker.

### D7. How are minimum and maximum boundaries compared?

Compare parsed local datetime parts at minute precision. Boundary moments are
inclusive. Missing minimum or maximum values leave that side unbounded.

### D8. Are nested parameter shapes allowed to change?

No. The migration must submit the same `date` attribute under the same nested builder
path. Visible controls do not have `name` attributes.

### D9. What happens on validation rerender?

The server-rendered record value wins. The shared controller projects it into visible
controls on connect, preserving entered minute precision.

### D10. Is the disabled user-card reference transport field included?

No. It is not a visible user datetime control and remains an intentional derived
transport field.

### D11. When is an installment datetime editable?

Datetime editability follows the existing installment row lock. Locked rows are
read-only; unlocking makes them editable; relocking restores read-only mode. The lock
controller applies its existing sequential row behavior to datetime controls.

### D12. Is the pay-in-advance window enforced by the backend?

Yes. One reusable window calculator supplies both modal limits and controller
validation. Out-of-range direct requests return a localized `422` and create no card
or cash records.

### D13. What does compact mode do on mobile?

Compact repeated rows use inline date and time controls on mobile and desktop. They do
not embed the expanded calendar/clock layout used by main transaction forms.

## Shared Control Test Matrix

| Scenario | Expected result |
| --- | --- |
| standard caller without new options | current markup and behavior preserved |
| calendar caller without new options | current calendar/time picker preserved |
| compact caller | inline stable date/time layout |
| read-only caller | visible editing blocked; hidden value enabled |
| disabled caller | visible and hidden controls disabled |
| no time control | canonical time fallback preserved |
| valid time formats (`8`, `830`, `08:30`) | normalized to `08:00` or `08:30` |
| invalid hour/minute | localized validation; submission blocked |
| value equals minimum | accepted |
| value before minimum | localized minimum error |
| value equals maximum | accepted |
| value after maximum | localized maximum error |
| parent writes canonical value | visible date/time/weekday refresh without loop |
| user commits visible value | hidden emits parent input/change once |

## Nested Installment Test Matrix

| Scenario | Expected result |
| --- | --- |
| render several persisted installments | unique hidden/date/time IDs |
| activate `NEW_RECORD` template repeatedly | every active row receives unique IDs |
| submit cash nested date | exact datetime persists |
| submit card nested date | exact datetime persists |
| cash source date changes | eligible unpaid dates and visible controls update |
| card source date changes | existing refresh/submission behavior preserved |
| previous/next reference month | month/year label and fields remain synchronized |
| cash date moves into past | paid-state behavior preserved |
| locked row during schedule regeneration | stored date remains unchanged |
| locked row renders | date/time visible but read-only; hidden value enabled |
| user unlocks row | date/time becomes editable without losing value |
| user relocks row | date/time becomes read-only without changing value |
| duplicate transaction | duplicated values render in hidden and visible controls |
| validation failure | entered date/time survives rerender |

## Nested Exchange Test Matrix

| Scenario | Expected result |
| --- | --- |
| standalone exchange renders | compact visible controls editable |
| standalone date changes | hidden date and month/year update once |
| standalone previous/next | hidden and visible dates remain synchronized |
| card-bound exchange renders | visible controls read-only; hidden enabled |
| card-bound previous/next | selected reference date populates hidden and visible values |
| user attempts card-bound edit | derived value cannot be changed |
| several exchanges render | unique IDs and correct nested names |
| exchanges added/removed/regenerated | active rows retain correct values and numbering |
| paid exchange structural rewrite | existing guard still rejects unsafe change |
| failed validation | entered standalone and derived card-bound values rerender correctly |

## Pay-In-Advance Test Matrix

| Scenario | Expected result |
| --- | --- |
| current time within window | current minute is default |
| current time outside window | maximum datetime is default |
| minimum missing | lower side unbounded |
| maximum missing | upper side unbounded |
| datetime equals minimum | accepted |
| datetime equals maximum | accepted |
| datetime outside window in UI | client feedback blocks the modal submission |
| direct request outside window | localized `422`; no card/cash records created |
| modal render | unique IDs and autofocus on visible date |
| valid submit | card advance and linked cash transaction created |
| derived context submit | both records remain in active context |

## Responsive and Manual Matrix

| Scenario | Expected result |
| --- | --- |
| narrow cash installment carousel | date/time, price, and lock do not overlap |
| narrow exchange carousel | date/time and price controls remain usable |
| desktop repeated rows | compact controls align across cards |
| light mode | editable/read-only/invalid states distinguishable |
| dark mode | borders, text, focus, and validation retain contrast |
| keyboard entry and Tab | normalized value committed without accidental submit |
| Enter on valid control | existing form submit behavior preserved |
| Turbo replacement | old controller disconnects and new value initializes cleanly |

## Blocking Product Decisions

There are no known blocking product decisions.
