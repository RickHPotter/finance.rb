# KAKASHI-14 Category Colours: Decisions and Test Matrix

## Resolved Product Decisions

### D1. Which accessibility standard applies?

Decision: WCAG 2.x relative luminance with a minimum `4.5:1` contrast ratio.

### D2. Does large or bold category text get the weaker `3:1` threshold?

Decision: no. All category labels use `4.5:1`, which keeps the component contract
independent of responsive font-size changes.

### D3. Which colour syntax is persisted?

Decision: lowercase six-digit opaque hex with a leading `#`.

### D4. Which user input is accepted?

Decision: three- or six-digit hex with an optional leading `#`. Three-digit input is
expanded before persistence.

### D5. Are named colours or alpha channels accepted?

Decision: no. Legacy palette names are translated during migration only. Transparency
cannot provide a stable contrast guarantee against every surrounding canvas.

### D6. How is automatic text selected?

Decision: compare pure black and pure white and choose the higher ratio. This gives the
strongest of the two predictable neutral foregrounds.

### D7. Is the automatic result stored?

Decision: no. It is derived so a background change cannot leave stale foreground data.

### D8. How is manual mode represented?

Decision: explicit `text_colour_mode: "manual"` plus a normalized `text_colour`.
Automatic mode clears the manual value.

### D9. What happens when a manual colour fails?

Decision: save fails with the measured ratio, required threshold, and automatic
suggestion. The server never silently changes an explicitly chosen manual colour.

### D10. What happens at exactly `4.5:1`?

Decision: it passes. Validation compares the unrounded ratio.

### D11. What happens to current category backgrounds?

Decision: they retain their exact rendered RGB values. Symbolic palette keys are
canonicalized to the hex values they resolve to at migration time.

### D12. What is authoritative?

Decision: the Ruby contrast service and model validation. JavaScript is an equivalent
preview, not a security or persistence boundary.

### D13. How do light and dark modes differ?

Decision: only the preview canvas/application surroundings differ. The category's
resolved background/foreground pair is stable in both themes.

### D14. How are multi-category gradients handled?

Decision: use individually resolved segments or a neutral bundle surface. A label may
overlay a gradient only when its foreground passes against every stop.

### D15. Can hover use `brightness-*` or opacity?

Decision: not on the labelled colour surface unless the resulting pair is measured.
Prefer borders, rings, shadows, or underlines that leave the accessible pair intact.

### D16. Do charts get a separate colour algorithm?

Decision: no. Server payloads provide the same resolved background and foreground.

### D17. How is the future row-colour user setting represented?

Decision: category-bearing transaction and budget rows accept one resolved display
mode: `row_coloured` or `badges_only`. `row_coloured` is the default until a user
preference is persisted.

In `row_coloured`, the first category in deterministic built-in-first allocation order
supplies its complete validated pair for the row. All assigned categories remain visible as their
own category-background badges. In `badges_only`, the row uses the normal application
surface and the badges alone carry category backgrounds. In either mode, every category
badge retains its own resolved foreground/border, while entity badge text/borders follow
the row foreground. Entity info uses its matching light/dark supporting tone. The
failed-return category comes
first, followed by other built-ins and then ordinary categories, for both badge order
and primary row selection; allocation order is preserved inside each remaining tier.
Empty, blank, and unknown modes safely resolve to `row_coloured`.

The setting is resolved at a controller/parent-view boundary and passed downward.
Leaf presenters do not reach into user persistence, which keeps the future settings
migration separate from colour rendering.

## Normalization and Contrast Matrix

| Scenario | Expected result |
| --- | --- |
| `#abc` | persists as `#aabbcc` |
| `ABC` | persists as `#aabbcc` |
| `#A1B2C3` | persists as `#a1b2c3` |
| `white` from legacy row | migrates through `COLOURS` to exact mapped hex |
| new submission `white` | rejected |
| `transparent` | rejected |
| `#aabbccdd` | rejected |
| `rgb(1, 2, 3)` | rejected |
| blank background | rejected |
| background `#ffffff` automatic | foreground `#000000` |
| background `#000000` automatic | foreground `#ffffff` |
| saturated mid-colour | higher-contrast black/white candidate |
| ratio exactly `4.5` | passes |
| unrounded ratio below `4.5` but displays `4.50` | fails |
| invalid hex passed to service | bounded invalid result/error, no guessed colour |

## Model and Persistence Matrix

| Scenario | Expected result |
| --- | --- |
| new category | automatic mode |
| automatic with submitted manual value | manual value cleared |
| manual without foreground | validation failure |
| manual foreground at/above threshold | saved canonically |
| manual foreground below threshold | validation failure with ratio/suggestion |
| background changes in automatic mode | resolved foreground recalculated |
| background changes in manual mode and remains valid | save succeeds |
| background changes and invalidates manual foreground | save fails |
| built-in category colour edit | allowed; name remains locked |
| unknown legacy palette key during migration | migration aborts with identifier |
| migration backfill | no background RGB changes |
| rollback | new columns removed; normalized backgrounds remain hex |

## Form and Client Matrix

| Scenario | Expected result |
| --- | --- |
| open new form | automatic selected and both previews visible |
| select palette swatch | background, ratio, and foreground update |
| type valid short hex | preview uses expanded value |
| type incomplete/invalid hex | invalid state, no invalid style or passing claim |
| switch to manual | foreground control shown |
| choose passing manual colour | pass state and measured ratio |
| choose failing manual colour | fail state and automatic suggestion |
| switch back to automatic | manual control hidden and derived foreground shown |
| server rejects value | form URL/values retained with concrete notification |
| keyboard use | mode, swatches, and inputs operable/labeled |
| light preview | pair visible on light canvas |
| dark preview | same pair visible on dark canvas |
| JS calculation fixture | matches Ruby result and ratio tolerance |

## Rendering Matrix

| Scenario | Expected result |
| --- | --- |
| category chip | resolved pair used |
| category selector option | resolved pair and accessible name |
| transaction row | resolved pair used |
| budget allocation | resolved pair used |
| category dashboard label | resolved pair used |
| filter summary | resolved pair used |
| disabled chip | label still reaches `4.5:1` |
| focused chip | ring visible against chip and surrounding canvas |
| selected chip | no unchecked generic foreground |
| multi-category row | segmented or neutral bundle treatment |
| gradient retained | chosen foreground passes every stop |
| `row_coloured`, one category | resolved pair colours both row and badge |
| `row_coloured`, multiple categories | built-in-first primary pair colours row; every category badge retains its own resolved text/border |
| `badges_only`, one category | normal application row; badge retains its own resolved text/border |
| `badges_only`, multiple categories | normal application row; every category badge retains its own resolved text/border |
| blank/unknown display mode | resolves to `row_coloured`; never reaches CSS |
| nil/missing category | neutral accessible fallback |
| dark mode | normal rows use their application foreground; coloured rows retain the primary foreground |
| internal/external ledger | same presentation contract |

## Chart and Payload Matrix

| Scenario | Expected result |
| --- | --- |
| one category | payload contains background and resolved foreground |
| category manual mode | payload foreground equals validated manual choice |
| multiple categories | deterministic neutral bundle pair or segment payload |
| legend | uses payload pair and visible text |
| tooltip | readable pair or accessible neutral tooltip |
| chart unavailable | text equivalent still identifies category/value |
| fallback palette | foreground resolved through same service |

## Display Mode Matrix

| Surface | `row_coloured` | `badges_only` |
| --- | --- | --- |
| cash transaction, desktop/mobile | primary category pair on row | normal application row |
| card transaction, desktop/mobile | primary category pair on row | normal application row |
| transaction sheet/ledger | primary category pair on row | normal application row |
| budget, desktop/mobile | primary category pair on row | normal application row |
| one category badge | own resolved foreground/border | own resolved foreground/border |
| multiple category badges | own resolved foreground/border; built-ins first | own resolved foreground/border; built-ins first |
| entity badges | primary row foreground/border | application row foreground/border |
| entity info | light supporting tone for a light foreground; dark otherwise | light/dark supporting tone follows theme |
| no categories | normal application row | normal application row |

Every row-mode example is covered with one and multiple categories. Tests must prove
that the row background and foreground come from the same presentation object and that
changing display mode does not change category ordering or hide allocations.

## Regression and Manual Matrix

| Scenario | Expected result |
| --- | --- |
| repository search for `auto_text_color` | no direct category-surface callers |
| repository search for category inline backgrounds | each consumes shared presentation or documented chart payload |
| category create/update requests | automatic and manual branches covered |
| cash/card/budget views | very light/dark/mid/saturated fixtures covered |
| English locale | complete labels/errors |
| Portuguese locale | complete labels/errors |
| desktop light/dark | normal and interactive states readable |
| mobile light/dark | picker, chips, rows, and previews usable |
| browser zoom/high text size | labels remain visible without relying on `3:1` exception |

## Remaining Product Decisions

There are no blocking V1 product decisions. Later work may consider:

- APCA reporting alongside WCAG without weakening the V1 gate
- curated accessible palette suggestions
- colour-vision-deficiency simulation
- additional chart patterns/shapes beyond the required text equivalent
