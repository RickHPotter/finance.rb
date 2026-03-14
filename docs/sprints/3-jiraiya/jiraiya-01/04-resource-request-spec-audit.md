# Jiraiya 01 Resource Request Spec Audit

## Status

Completed minimal resource coverage sweep.

## What Was Done

Added request specs for:

- `UserBankAccounts`
- `UserCards`
- `Categories`
- `Entities`
- `Budgets`
- `Investments`
- `Conversations`
- `Static`

Also completed:

- renamed `PagesController` to `StaticController`
- moved donation and notification views to the new controller namespace
- kept legacy `/pages/*` routes temporarily mapped for compatibility

## Key Decisions

- these specs are intentionally shallow and prove only the main controller contract
- Turbo Stream headers are used where the controller responds through Turbo-only save flows
- category/entity happy-path specs create a `UserCard` first because those controllers intentionally branch into card-transaction setup

## Remaining Gaps

Not covered in this sweep:

- deeper invalid-state cases
- richer conversation/message flows
- eventual removal of legacy `/pages/*` compatibility routes

## Next Recommendation

Keep this layer minimal unless one of these resource controllers starts changing heavily in Sprint 3.
