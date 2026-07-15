# KAKASHI-06 Balances Monthly Analysis: Product and Data Contract

## Goal

Add a lazy-loaded `Monthly Analysis` tab to `/balances` so one selected month can
be understood through ordinary income, ordinary outcome, category allocation,
entity allocation, person-to-person transfers, and piggy-bank savings activity.

The existing modern balances dashboard remains the default `Overview` tab. Its
summary, trend, extremes, and selected-month breakdown behavior must remain stable.
`/balances/legacy` remains untouched and continues to be the only ApexCharts balances
surface.

## Source Decisions

This plan amalgamates the two previous implementation attempts. Version Two is the
authoritative financial contract. Version One contributes the lazy Turbo-frame
boundary, compact monthly controls, Chart.js lifecycle patterns, textual chart
legends, and explicit loading/empty/error states.

The following Version One rules are rejected:

- entity totals derived from prorated `EntityTransaction#price_to_be_returned`
- transfer-family transactions rendered as an ordinary synthetic category
- category/entity mode switching that hides half of the analysis at a time

These rules failed to produce one consistently reconcilable view of actual movement.
Both attempts also predated KAKASHI-05, so this contract adds Piggy Bank activity as a
third financial dimension rather than misclassifying principal as spending or income.

## Current Surface

`Views::Balances::Mobile` is the modern `/balances` surface. It currently:

- loads current, low, and high balance summaries
- renders balance trend and monthly extremes with Chart.js
- renders an existing selected-month category breakdown
- scopes its finder calls through `current_context`

KAKASHI-06 adds a sibling analysis surface. It does not extend the legacy-shaped
`Logic::Finder::TransactionBalanceJson` payload because that finder includes budgets
and can duplicate installment values through category joins.

## Monthly Boundary

The analysis covers exactly one calendar month at a time.

- The initial selection is the current calendar month.
- Previous, next, and month-picker controls replace the selected month.
- Ordinary cash and card movement is attributed by each installment's own `month`
  and `year`, never only by its parent transaction.
- Monetary transfers are attributed by each `Exchange` row's own `month` and `year`.
- Failed lend/borrow returns are attributed by the failed cash installment's own
  `month` and `year`.
- Invalid or missing month input must return a controlled validation response; it
  must not silently substitute another month.

## Context Boundary

Every read must be scoped to `current_context`, including derived scenario contexts.

The finder must begin from context-owned cash installments, card installments, cash
transactions, and card transactions. A direct `Exchange` query is allowed only when
its eligible parent transaction IDs have already been obtained from the current
context. Empty eligible ID sets must produce empty transfer data rather than a broad
query.

## Ordinary Movement

Ordinary movement includes:

- cash installments in the selected month
- card installments in the selected month

Ordinary movement excludes:

- budgets
- generated card-payment cash transactions with
  `cash_transaction_type: "CardInstallment"`
- aggregate cash projections with `cash_transaction_type: "Investment"`; linked Piggy
  Bank valuations are read directly from Investment rows, while unlinked legacy
  Investments remain outside V1
- any transaction classified as a transfer source
- `PIGGY BANK` contributions and generated `PIGGY BANK RETURN` transactions
- failed lend/borrow return rows, which belong to the Transfers panel

The installment's signed price is authoritative:

- positive installment price is income
- negative installment price is outcome
- outcome is aggregated as an absolute amount for display
- net ordinary movement is signed income plus signed outcome

All aggregation must remain in integer cents until the response boundary. Conversion
to major currency units occurs once when serializing the JSON payload.

## Deterministic Allocation Bundles

Every ordinary installment contributes its full amount exactly once to one category
bundle and exactly once to one entity bundle.

Examples:

- categories `Food` and `Transport` become `Food + Transport`
- entities `Ana` and `Bruno` become `Ana + Bruno`
- no linked records become the localized `Unassigned` bucket

The amount is not divided among linked records and is not repeated for every linked
record. A July installment of `-40` assigned to Ana and Bruno contributes one `40`
outcome row to `Ana + Bruno`, not `40` to each person.

Bundle construction rules:

1. Use the models' stable ordering, with ID as the final tiebreaker.
2. Aggregate by a stable signature of allocation IDs, not by the translated label.
3. Build the display label after the signature is known.
4. Preserve source type and installment identity before eager-loading allocations so
   joins cannot duplicate the source amount.
5. Use a single category's configured color for a one-category bundle.
6. Use a neutral, contrast-safe color for multi-category and unassigned bundles.
7. Entity bundles use a neutral chart color; they do not imply proportional ownership.

`EntityTransaction#price_to_be_returned` is deliberately not used for ordinary entity
analysis. It represents an expected return/debt contract, not the actual installment
movement for the selected month.

## Special-Movement Classification

Every source is assigned to at most one analysis family in this order:

1. generated card-payment cash row: excluded
2. failed lend/borrow return: failed Transfers section
3. exchange-family source: normal Transfers section
4. piggy-bank source or generated return: Piggy Banks section
5. everything else: ordinary movement

The existing category validations prevent exchange and piggy-bank families from being
combined. The precedence still makes historical or corrupted rows deterministic and
prevents any source from contributing to two analysis families.

## Transfer Classification

A cash or card transaction is transfer-classified when it contains any of these
built-in categories:

- `EXCHANGE`
- `EXCHANGE RETURN`
- `BORROW RETURN`
- `FAILED LEND/BORROW RETURN`

Transfer-classified transactions are excluded wholesale from ordinary category and
entity aggregation, even if an invalid or historical row also carries a normal
category. This prevents one movement from appearing in both ordinary and transfer
totals.

The UI groups the first three categories under the localized concept `Transfers` /
`Transferências`, but this is a separate panel rather than an ordinary chart bucket.

## Monetary Transfers

Normal transfers are calculated from monetary `Exchange` rows:

- use `Exchange#price` as the amount source
- include only `Exchange.monetary`
- use the exchange row's month/year
- preserve the associated entity as the counterparty
- derive `sent` or `received` from `EntityTransaction#is_payer`
- aggregate by stable entity ID and direction
- count every eligible exchange ID once
- show amounts as positive magnitudes while keeping direction explicit

Do not use the parent installment price or `price_to_be_returned` for this panel. The
exchange rows already describe the actual monetary allocations and their timing.

The panel reports separate totals for sent and received values. V1 does not net these
directions into one number because netting would hide the actual flow between people.

## Failed Transfers

`FAILED LEND/BORROW RETURN` is displayed separately from sent and received transfers.

- use the affected cash installment's `starting_price` as the neglected amount
- preserve a machine-readable `failed` state
- identify the entity bundle deterministically
- do not include the failed amount in ordinary income/outcome
- do not include it in sent/received totals

This distinction is required because the failed flow may have a current price of zero
after the neglected amount has been recorded in `starting_price`.

## Piggy Bank Savings

`PIGGY BANK` and generated `PIGGY BANK RETURN` cash transactions are internal savings
movements. They do not represent ordinary spending or ordinary income.

The separate Piggy Banks section reports:

- **contributions** from `PIGGY BANK` source cash installments, attributed by each
  source installment's month/year and shown as positive magnitudes
- **withdrawals** from generated `PIGGY BANK RETURN` cash installments, attributed by
  each return installment's month/year
- **recognized profit/loss** from `Investment` rows explicitly linked through
  `piggy_bank_return_cash_transaction_id`, attributed by each investment's month/year
- **net saved movement** as all scheduled contributions minus all scheduled withdrawals
  for the selected month
- separate realized and projected contribution/withdrawal amounts using each
  installment's paid state; the UI must not present an unpaid row as realized cash

Contribution and withdrawal rows aggregate by stable Piggy Bank return-group ID and
retain the group's description so several piggy banks at the same entity remain
distinguishable. Several contributions attached to one return group aggregate into
that group without losing the individual source installment identities used for
deduplication.

Profit/loss rules:

- positive linked `Investment#price` is recognized profit
- negative linked `Investment#price` is recognized loss
- linked values are reported for their own selected month even though they also revise
  the future return projection
- profit/loss is not inferred by subtracting principal from the projected return
- unlinked legacy `Investment` rows are excluded from this section

A return installment contains principal plus all recognized valuation changes applied
to its group. Therefore the withdrawal total and recognized profit/loss are different
views and must not be added together as one grand movement total. The section presents
them separately and explains whether a withdrawal is projected or paid.

## Response Contract

The dedicated finder returns one bounded payload:

```json
{
  "month": "2026-07",
  "ordinary": {
    "income": {
      "total": 4200.0,
      "categories": [
        { "key": "category:12", "label": "Salary", "amount": 4200.0, "color": "#15803d" }
      ],
      "entities": [
        { "key": "entity:7", "label": "Employer", "amount": 4200.0 }
      ]
    },
    "outcome": {
      "total": 1600.0,
      "categories": [
        { "key": "categories:4+9", "label": "Food + Transport", "amount": 1600.0, "color": "#78716c" }
      ],
      "entities": [
        { "key": "entities:2+3", "label": "Ana + Bruno", "amount": 1600.0 }
      ]
    },
    "net": 2600.0
  },
  "transfers": {
    "total_sent": 500.0,
    "total_received": 125.0,
    "items": [
      { "entity_id": 2, "entity_label": "Ana", "direction": "sent", "amount": 500.0 }
    ],
    "failed": [
      { "key": "entities:3", "entity_label": "Bruno", "amount": 75.0, "state": "failed", "amount_source": "starting_price" }
    ]
  },
  "piggy_banks": {
    "total_contributed": 800.0,
    "total_projected_contribution": 0.0,
    "total_withdrawn": 0.0,
    "total_projected_withdrawal": 808.0,
    "recognized_profit_loss": 8.0,
    "groups": [
      {
        "return_cash_transaction_id": 91,
        "label": "Three-month reserve",
        "contributed": 800.0,
        "projected_contribution": 0.0,
        "withdrawn": 0.0,
        "projected_withdrawal": 808.0,
        "recognized_profit_loss": 8.0
      }
    ]
  }
}
```

Rows are ordered by amount descending and then label/key for deterministic ties.
Payload keys and direction/state values remain language-neutral. Labels, explanatory
copy, and currency presentation follow the current user's locale.

## User Interface Contract

`/balances` becomes a two-tab surface:

1. `Overview`
   - selected and rendered by default
   - preserves existing requests and interactions
2. `Monthly Analysis`
   - contains a lazy Turbo frame
   - does not render its analysis markup or request JSON until first activation
   - keeps the loaded frame available when the user returns to Overview

The analysis surface contains:

- previous-month icon button
- shared month control or a month input consistent with the balances surface
- next-month icon button
- income, outcome, and net summary values
- income by category bundle
- outcome by category bundle
- income by entity bundle
- outcome by entity bundle
- a separate Transfers panel with sent, received, and failed sections
- a separate Piggy Banks panel with paid/projected contributions and withdrawals, plus
  recognized profit/loss by return group

The four ordinary breakdowns remain available together. Desktop may use two columns;
mobile stacks them. Each chart has a textual ranked list so the values remain readable
without canvas output. Fixed chart dimensions prevent data or loading states from
shifting the surrounding layout.

Loading, empty, request-error, and retry states must be explicit. A month with only
transfers or Piggy Bank activity is not an empty month. A failed JSON request must
retain the selected month and allow a deliberate retry.

## Frontend Safety and Lifecycle

- Use the existing Chart.js dependency; do not introduce ApexCharts.
- Keep tab/lazy-frame behavior separate from the monthly chart controller.
- Destroy every Chart.js instance before replacing data and on Stimulus disconnect.
- Abort or ignore stale requests when the user changes months quickly.
- Render server-provided labels with `textContent` or equivalent safe DOM APIs; do not
  interpolate entity/category labels into `innerHTML`.
- Obtain locale and currency from the page or server contract; do not hard-code
  `pt-BR` or `BRL` inside the controller.
- Use existing icon components for previous, next, retry, and other familiar actions.
- Preserve dark-mode contrast for chart axes, grids, bars, text lists, and states.

## Non-Goals

- replacing or removing `/balances/legacy`
- migrating the legacy ApexCharts controller
- comparing several months in the new tab
- export, drill-down, or arbitrary analysis filters
- editing financial records from charts
- splitting one installment among several categories or entities
- changing allocation persistence
- treating transfers as ordinary income/outcome
- calculating profitability or debt settlement from `price_to_be_returned`
