# Jiraya 01 Request Spec Audit

## Status

Completed first pass and follow-up pass.

## What Was Done

Extended existing request coverage for:

- `CardTransactions`
  - `duplicate`
  - `pay_in_advance`
- `CashTransactions`
  - `create`
  - `update`
  - `destroy`
  - `month_year`

Added new request coverage for:

- `References`
- `CashInstallments`
- `Messages`
- `Subscriptions`
- `NamingConventions`

## Key Decisions

- aligned request specs with current Turbo Stream controller contracts
- used redirects only where the controller genuinely redirects
- kept request specs focused on real product flows instead of idealized REST semantics
- `Reference` manual edit behaviour now bypasses automatic closing-date recalculation

## Remaining Gaps

Likely still low-value or future-only:

- deeper auth/ownership edge cases
- more invalid-state request coverage

## Next Recommendation

Only add more request specs when a concrete workflow proves risky or unstable during Sprint 3 feature work.
