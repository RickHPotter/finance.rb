# SUMMARY

<!--toc:start-->
- [SUMMARY](#summary)
  - [INTRODUCTION](#introduction)
  - [SPRINT PLANNING II: SASUKE](#sprint-planning-ii-sasuke)
    - [SASUKE-01/app-01: Update stack and infrastructure again](#sasuke-01app-01-update-stack-and-infrastructure-again)
    - [SASUKE-02/be-01: Refine payments, references, and financial consistency](#sasuke-02be-01-refine-payments-references-and-financial-consistency)
    - [SASUKE-03/fe-01: Improve transaction flows and bulk actions](#sasuke-03fe-01-improve-transaction-flows-and-bulk-actions)
    - [SASUKE-04/fe-02: Improve PWA and navigation experience](#sasuke-04fe-02-improve-pwa-and-navigation-experience)
    - [SASUKE-05/app-02: Create chat, notifications, and communication flows](#sasuke-05app-02-create-chat-notifications-and-communication-flows)
    - [SASUKE-06/be-02: Refine domain rules around exchanges, installments, and balances](#sasuke-06be-02-refine-domain-rules-around-exchanges-installments-and-balances)
    - [SASUKE-07/fe-03: Improve naming conventions, filters, and table UX](#sasuke-07fe-03-improve-naming-conventions-filters-and-table-ux)
    - [SASUKE-08/app-03: Performance pass and maintenance cleanup](#sasuke-08app-03-performance-pass-and-maintenance-cleanup)
<!--toc:end-->

## INTRODUCTION

__30/Fev__ kept its original goal during this sprint: turn personal finance management
into something practical, visual, and consistent enough to be used every day.

Sprint 2 was much less about making the app exist and much more about making it
behave like a real product: better flows, better navigation, stronger mobile/PWA
support, cleaner financial rules, and enough operational tooling to maintain the app
without improvisation.

## SPRINT PLANNING II: SASUKE

Starting point for the phase where the project stopped being just an MVP and started
being hardened as a product.

__SASUKE__ was not planned with the same discipline as Sprint 1. In practice, it was a
long sequence of fixes, improvements, and product ideas that gradually became large
enough to deserve its own sprint. Much of what happened here could have been called
`Sprint 1.5`, but the volume of changes made it clear that this was already another stage.

In theory, the `SASUKE` sprint phase did not exist in the same way `GAARA` sprint did.
The tasks below were written after the sprint was finished for no other reason other
than aesthetically, and that is why the tasks and their descriptions might feel a little shy.

### SASUKE-01/app-01: Update stack and infrastructure again

- Subtasks:
  - ✅ Successfully update the stack again until reaching `Ruby 4.0.0` and `Rails 8.1`.
  - ✅ Move from `Action Cable` to `Solid Cable`.
  - ✅ Rework deployment and maintenance concerns.
- Extra:
  - ✅ Add backup and restore tasks.
  - ✅ Add backup mailer delivery.
  - ✅ Replace scheduler usage with cron-based scheduling.
  - ✅ Deal with VPS, domain, and deployment adjustments.
  - ✅ Address security and dependency updates.

### SASUKE-02/be-01: Refine payments, references, and financial consistency

- Subtasks:
  - ✅ Add stronger `ref_month_year` handling.
  - ✅ Add reference editing and merging flows.
  - ✅ Add partial payment support for cash installments.
  - ✅ Make investment types required.
- Extra:
  - ✅ Fix edge cases around due dates, reference dates, and card-payment behaviour.

### SASUKE-03/fe-01: Improve transaction flows and bulk actions

- Subtasks:
  - ✅ Add transfer-multiple flow.
  - ✅ Improve pay-multiple flow.
  - ✅ Improve duplication speed and repeated transaction entry.
- Extra:
  - ✅ Reduce friction in the main day-to-day transaction actions.

### SASUKE-04/fe-02: Improve PWA and navigation experience

- Subtasks:
  - ✅ Improve app-like navigation and reduce SPA-style detours.
  - ✅ Refine mobile and PWA layouts across transactions, budgets, and investments.
  - ✅ Improve Turbo/Hotwire navigation patterns.
- Extra:
  - ✅ Add history navigation controls.
  - ✅ Add calculator modal and related utility flows.
  - ✅ Continue visual cleanup around responsiveness and navigation cues.

### SASUKE-05/app-02: Create chat, notifications, and communication flows

- Subtasks:
  - ✅ Implement chat and message flow.
  - ✅ Add push notifications for the PWA.
- Extra:
  - ✅ Establish the first version of communication features that can support future
    assistant-oriented work.

### SASUKE-06/be-02: Refine domain rules around exchanges, installments, and balances

- Subtasks:
  - ✅ Refine exchanges and installments so both behave more consistently.
  - ✅ Improve balance recalculation timing.
  - ✅ Reduce unnecessary recalculation runs.
  - ✅ Attach references to exchange cash transactions.
- Extra:
  - ✅ Fix inconsistencies around budgets, exchanges, grouped transaction counts, and
    related callbacks.

### SASUKE-07/fe-03: Improve naming conventions, filters, and table UX

- Subtasks:
  - ✅ Add naming-convention linting flow for transaction descriptions.
  - ✅ Improve filters and ordering flows in transaction pages.
  - ✅ Add sticky bulk actions, confirmation modals, and tab notifications.
- Extra:
  - ✅ Continue component extraction and richer UI feedback around listing screens.

### SASUKE-08/app-03: Performance pass and maintenance cleanup

- Subtasks:
  - ✅ Add a Bullet-driven performance pass.
  - ✅ Clean recurring N+1 issues.
  - ✅ Reduce brittle frontend/backend behaviour through several bug-fix rounds.
  - ✅ Continue refactoring toward more modular components, services, and controllers.
- Extra:
  - ✅ Leave the project in a much stronger position for a more deliberately planned Sprint 3.
