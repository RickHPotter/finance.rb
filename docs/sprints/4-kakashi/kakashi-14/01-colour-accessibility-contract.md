# KAKASHI-14 Category Colours: Accessibility Contract

## Objective

Guarantee that category text and interactive states remain readable for every accepted
category background in light mode, dark mode, forms, selectors, transaction rows,
budgets, dashboards, charts, and legends.

The server owns the colour decision. The browser may preview that decision but must
not establish a second accessibility rule.

## Locked Product Decisions

- The minimum contrast ratio is WCAG 2.x AA `4.5:1`.
- The same threshold applies to all category labels. V1 does not weaken the requirement
  for larger or bold text.
- Category background and manual text colours are persisted as lowercase `#rrggbb`.
- Form input may contain `rgb`, `#rgb`, `rrggbb`, or `#rrggbb`; successful
  normalization always expands it to six digits with a leading `#`.
- Alpha channels, transparency, CSS colour names, CSS functions, and malformed values
  are rejected.
- Existing symbolic palette values are a migration concern only. They are translated
  through the current `COLOURS` mapping without changing the displayed background.
- Text-colour mode is an explicit string-backed value: `automatic` or `manual`.
- New and backfilled categories default to `automatic`.
- Automatic mode compares pure black (`#000000`) and pure white (`#ffffff`) and returns
  the candidate with the greater contrast ratio.
- Manual mode accepts any normalized opaque hex foreground that reaches `4.5:1`.
- A failing manual choice is not silently replaced on save. Validation shows the
  measured ratio and the accessible automatic suggestion.
- Automatic foregrounds are derived when used and are not persisted. This prevents a
  background edit from leaving a stale resolved foreground.
- Light and dark previews show the category surface inside both surrounding themes.
  The category background and foreground themselves remain identical.
- Multi-category bundles do not put one label over an unchecked gradient. They use
  individually resolved segments, or a neutral bundle surface when segmentation is
  unsuitable.

## Persistence Contract

Add these category attributes:

| Attribute | Type | Null/default | Meaning |
| --- | --- | --- | --- |
| `colour` | string | non-null | normalized background `#rrggbb` |
| `text_colour_mode` | string | non-null, `automatic` | string-backed mode |
| `text_colour` | string | nullable | normalized manual foreground only |

Model behavior:

- normalize colour input before validation
- validate the mode inclusion
- require `text_colour` in manual mode
- clear `text_colour` in automatic mode
- reject a manual foreground below `4.5:1`
- expose `resolved_text_colour` and the measured contrast without duplicating the WCAG
  calculation in the model
- retain user-scoped category-name and built-in-category behavior

The migration backfills each existing `colour`:

1. expand a valid short hex
2. normalize a valid six-digit hex
3. translate a known legacy `COLOURS` key to its exact current hex
4. fail the migration with a useful category identifier for an unknown value rather
   than inventing a replacement
5. set `text_colour_mode` to `automatic`

The schema rollback removes the new text-colour columns. It cannot restore symbolic
palette names after canonicalization, and the migration must disclose that fact.

## Central Contrast Service

Introduce one pure Ruby colour value/contrast service under a focused namespace. It
owns:

- input normalization
- hex-to-sRGB conversion
- sRGB linearization
- relative luminance
- contrast ratio
- automatic foreground selection
- manual foreground validation
- stable ratio formatting for messages and UI

Use the WCAG 2.x constants:

```text
channel <= 0.04045
  ? channel / 12.92
  : ((channel + 0.055) / 1.055) ** 2.4

contrast = (lighter_luminance + 0.05) / (darker_luminance + 0.05)
```

The comparison uses the unrounded ratio. Rounding is display-only. Exactly `4.5:1`
passes.

The existing `ColoursHelper#auto_text_color` and its private contrast implementation
must be retired or reduced to delegating compatibility wrappers during migration.
Views must not parse hex or guess foregrounds.

## Presentation Contract

Provide one category-colour presentation API that can be used by Phlex views,
components, helpers, and serializers. Given one category, it exposes:

- normalized background
- resolved foreground
- measured contrast ratio
- readable border colour
- readable focus-ring colour
- disabled-state style
- selected-state style
- chart background and foreground

Prefer a reusable category badge/swatch component for visible labels. For surfaces
whose markup cannot use that component, consume the same presentation object or helper.

### State treatment

- Hover must not use an unmeasured brightness/filter change that can invalidate
  contrast. Prefer outline, shadow, underline, or an already-checked state pair.
- Focus rings must contrast with both the category surface and its surrounding
  light/dark canvas. A two-layer ring is acceptable.
- Borders remain visible when foreground and background are near the surrounding
  canvas.
- Disabled state may reduce emphasis through surrounding decoration, but category
  label text must retain `4.5:1`.
- Selected state must not swap in a generic white or dark text class without checking
  the selected background.

### Multi-category bundles

A foreground is valid over a multi-colour background only if it reaches `4.5:1`
against every colour underneath it.

Preferred rendering order:

1. render one labelled/accessible segment per category with its own resolved pair
2. when one combined label is required, use a neutral application surface and show
   category colours as separate swatches
3. use a gradient behind text only when one foreground passes against every stop and
   the browser rendering does not introduce transparency

The first category's foreground is never assumed to represent the bundle.

## Category Form Contract

The category form includes:

- the existing background picker, upgraded to normalized opaque hex input
- `Automatic` and `Manual` text-colour mode controls
- a manual foreground picker visible only in manual mode
- current measured contrast, threshold, pass/fail state, and automatic suggestion
- representative chip previews on light and dark surrounding canvases
- normal, hover, focus, selected, and disabled examples

The Stimulus preview implements the same normalization and contrast equations as Ruby.
It gives immediate feedback, but server validation remains authoritative. Invalid
input must not produce `NaN`, an invalid inline style, or a falsely passing preview.

Built-in categories retain editable colours and text-colour preferences even when
their names remain locked.

## Charts and Data Payloads

Every category-bearing chart/legend payload includes both:

- `background_colour`
- `text_colour`

Client chart code must use those fields for labels, tooltips, legends, and accessible
text equivalents. A deterministic neutral pair represents multi-category bundles
unless the payload carries independently styled category segments.

Existing payload keys may be retained temporarily for compatibility, but one
authoritative builder must populate the resolved pair.

## Surface Inventory

The initial repository audit found category colours in:

- category index, show, and form views
- category allocation fields
- cash and card installment indexes and detail dashboards
- cash/card transaction forms and detail views
- budget forms, indexes, allocations, and dashboards
- investment month/year surfaces
- subscriptions
- entity, user-card, and bank-account dashboards
- internal/external ledger installment views
- standalone transaction sheets
- monthly-analysis JSON
- pie breakdown charts and legends

This list is a migration checklist, not permission to update only the named files.
The final sweep searches all Ruby, Phlex, ERB, JavaScript, serializers, and chart
payloads for raw category background usage and hardcoded foreground assumptions.

## Accessibility Semantics

- Colour is supplementary; category names remain present in text or accessible labels.
- A coloured empty swatch receives an accessible category label when it is interactive
  or conveys information.
- Validation messages announce failure and include the measured ratio.
- Picker controls are keyboard reachable and expose selected/mode state.
- Charts retain a text equivalent and never communicate category identity only by
  colour.

## Explicitly Out of Scope

- configurable WCAG thresholds
- APCA as a replacement contrast algorithm
- translucent category backgrounds or foregrounds
- gradients as a user-entered category colour
- automatic palette redesign
- changing existing category backgrounds to a preferred brand palette
- guaranteeing contrast inside exported third-party documents not rendered by this app
