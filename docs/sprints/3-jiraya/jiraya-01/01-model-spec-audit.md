# Jiraya 01 Model Spec Audit

## Status

Completed first pass.

## What Was Done

- added direct coverage for `Reference`
- added direct coverage for `InvestmentType`
- updated stale specs for `User`
- updated stale specs for `Investment`
- updated stale specs for `CashTransaction`
- updated stale specs for `CardTransaction`
- updated stale specs for `UserCard`
- added a `Reference` factory to support the new coverage

## Key Decisions

- `Reference` edit flow now allows manual `reference_closing_date` changes through the controller update path
- transaction model specs were kept focused on model contracts, not controller flow details

## Remaining Gaps

Still uncovered or only lightly covered:

- `Conversation`
- `Message`
- `ConversationParticipant`
- `Subscription`
- `BudgetCategory`
- `BudgetEntity`

Lower priority:

- `Installment`
- `Item`

## Next Recommendation

Do not expand model coverage further unless one of the remaining models becomes active Sprint 3 product work.
