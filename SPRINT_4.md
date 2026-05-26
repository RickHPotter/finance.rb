# SUMMARY

## INTRODUCTION

Sprint 4 starts from a Sprint 3 codebase that is accepted as functionally complete.
The remaining work below is not treated as unfinished Sprint 3 scope. It is the
deliberate product, UX, and operational follow-up that should be planned separately
instead of keeping JIRAIYA open.

## SPRINT PLANNING IV

### Follow-up 01: Reporting and index refinement

Source: JIRAIYA-03.

Carry forward only if the product need becomes clear:

- Budget index sorting.
- Mixed cash-plus-budget row sorting.
- A free-form query language or reserved parser parameter for advanced filtering.

These were intentionally left out of Sprint 3 because the shipped `sort` +
`direction` contract and explicit filter controls solved the immediate transaction
index problem without expanding the query model too early.

### Follow-up 02: Data-entry expansion

Source: JIRAIYA-05.

Possible Sprint 4 scope:

- Revisit date controls for installment-specific and exchange-specific forms.
- Decide whether `Budget` duplication should exist.
- Decide whether `Subscription` duplication should exist.
- Decide whether partial payment should expand beyond the current deterministic
  cash-installment flow.

These are product decisions, not backend safety blockers.

### Follow-up 03: Conversation and assistant hardening

Source: JIRAIYA-08.

Core context-aware conversation scoping is complete, but Sprint 4 can harden the
operational surface:

- Finish homolog/manual validation with two real users and multiple derived
  scenarios.
- Improve scenario visibility in conversation screens so users can immediately see
  whether they are acting in `main_context` or a derived scenario.
- Add broader browser-level/system coverage for wrong-scenario denial, unread
  isolation, receiver auto-cloning, and assistant apply flows.
- Watch for duplicate assistant-thread creation in the same user pair/scenario.

Silent fallback to `main_context` remains the highest-risk regression class for this
area.

### Follow-up 04: Reminder operations

Source: JIRAIYA-06.

Due-payment reminders are no longer limited to `User.first`; delivery iterates all
users while selecting only each user's `main_context` installments.

Potential Sprint 4 work:

- Add production observability around reminder delivery counts, failures, and push
  subscription cleanup.
- Decide whether tomorrow-only reminders should ever send email or push.
- Revisit push/email behavior after enough real mobile/PWA usage data exists,
  especially on iPhone.

### Follow-up 05: Dashboard evolution

Source: JIRAIYA-07.

Cash, card, budget, bank-account, user-card, category, and entity dashboards are
accepted as shipped. Future dashboard work should be treated as new product scope:

- Additional analytics/reporting pages.
- More cross-dashboard navigation.
- New dashboard models, if the workflow justifies them.
- Further chart or breakdown refinements after real usage.

## CLOSURE NOTE

Sprint 3 can close with these follow-ups moved into Sprint 4. None of the items
above should keep the JIRAIYA sprint open unless a new regression is found in the
accepted shipped behavior.
