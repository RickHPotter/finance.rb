# SUMMARY

<!--toc:start-->
- [SUMMARY](#summary)
  - [INTRODUCTION](#introduction)
  - [SPRINT PLANNING III: JIRAIYA](#sprint-planning-iii-jiraiya)
    - [JIRAIYA-01/app-01: Increase confidence and continue refactoring](#jiraiya-01app-01-increase-confidence-and-continue-refactoring)
    - [JIRAIYA-02/be-01: Create a first-class `Subscription` flow](#jiraiya-02be-01-create-a-first-class-subscription-flow)
    - [JIRAIYA-03/fe-01: Rethink datatables, filters, and ordering](#jiraiya-03fe-01-rethink-datatables-filters-and-ordering)
    - [JIRAIYA-04/be-02: Tighten financial safety rules](#jiraiya-04be-02-tighten-financial-safety-rules)
    - [JIRAIYA-05/fe-02: Consolidate data entry UX](#jiraiya-05fe-02-consolidate-data-entry-ux)
    - [JIRAIYA-06/app-02: Create `Context` as scenario planning](#jiraiya-06app-02-create-context-as-scenario-planning)
    - [JIRAIYA-07/fe-03: Create detail dashboards for core finance models](#jiraiya-07fe-03-create-detail-dashboards-for-core-finance-models)
    - [JIRAIYA-08/fe-04: Refine conversations and create a first assistant flow](#jiraiya-08fe-04-refine-conversations-and-create-a-first-assistant-flow)
  - [CONCLUSION](#conclusion)
<!--toc:end-->

## INTRODUCTION

Sprint 1 created the base of the product and Sprint 2 made it feel much closer to a
real application. Sprint 3 should be the sprint where the app becomes more coherent,
more predictable, and easier to trust on a daily basis.

At this stage, the biggest gaps are no longer the absence of core models. The main
opportunity now is to improve recurrence, speed up data entry, strengthen business
rules, improve analysis screens, and reduce the parts of the codebase that still feel
transitional.

## SPRINT PLANNING III: JIRAIYA

Sprint 3 should be planned more deliberately than Sprint 2. The goal is not to chase
many disconnected fixes, but to pick a few product and architecture gaps that are now
too visible to ignore.

### JIRAIYA-01/app-01: Increase confidence and continue refactoring

- Issues:
  - [#27](https://github.com/RickHPotter/finance.rb/issues/27)

- Subtasks:
  - Review outdated model specs and align them with the validations, associations,
  - Review outdated concern specs and align them with the current shared business rules.
  - Review outdated request specs and align them with current controller and product behaviour.
    predicates, and callback rules that still belong at model level.
- Extra:
  - Use this sprint to reduce transitional code, not just to add new features.
  - Models group, passive/domain records: `bank`, `card`, `category`, `entity`,
    `user`, `user_card`, `user_bank_account`, `investment`.
  - Models group, transaction records: `card_transaction`, `cash_transaction`,
    `exchange`, `entity_transaction`, `category_transaction`.
  - Models group, installment/date/planning records: `card_installment`,
    `cash_installment`, `budget`, `ref_month_year`.
  - Concerns group: `cash_transactable_spec`, `exchange_cash_transactable_spec`,
    `category_transactable_spec`, `entity_transactable_spec`, `budgetable_spec`.
  - Requests group: `card_transactions_spec`, `cash_transactions_spec`, `pages_spec`,
    and any missing request specs for current Sprint 2 features.
  - Removed unused gem jbuilder.
  - Removed unused js libs (TomSelect, chart.js, chartkick, flowbite-datepicker, and stimulus-use).
  - Removed unused stimulus controllers (AutocompleteSelect, DarkMode, and Datepicker)

### JIRAIYA-02/be-01: Create a first-class `Subscription` flow

- Issues:
  - [#28](https://github.com/RickHPotter/finance.rb/issues/28)

- Subtasks:
  - Create a built-in category or equivalent convention for subscription-generated
    records.
  - Create a dedicated `Subscription` concept instead of forcing recurrence into
    regular transactions.
  - Support monthly recurrence, fixed-term recurrence, and renewable plans.
  - Allow a subscription to generate either `CardTransaction` or `CashTransaction`.
  - Track enough metadata to explain lifecycle, such as start date, renewal date,
    status, and pause/finish state.
- Extra:
  - NA.

### JIRAIYA-03/fe-01: Rethink datatables, filters, and ordering

- Issues:
  - [#29](https://github.com/RickHPotter/finance.rb/issues/29)

- Subtasks:
  - Rework transaction indexes so ordering can be triggered from the table header.
  - Improve the current filtering model and make it more expressive.
  - Keep common filters simple while leaving room for a more advanced query syntax.
- Extra:
  - Review whether current index screens need a dedicated search language or just a
    stronger structured filter UI.

### JIRAIYA-04/be-02: Tighten financial safety rules

- Issues:
  - [#30](https://github.com/RickHPotter/finance.rb/issues/30)

- Subtasks:
  - Prevent edits to locked installments and exchanges when that would break paid
    history.
  - If unlocking is allowed, require an explicit warning flow.
  - Extend `PayMultiple` to support partial payment where the rules are clear enough.
  - Make lend-return and exchange-related cash flows stay in sync when installment
    structure changes.
  - Revisit category assignment so reporting can move from loose category stacking to
    clearer allocation.
- Extra:
  - Keep this part narrow and rule-driven; it is easy for these changes to become too broad.

### JIRAIYA-05/fe-02: Consolidate data entry UX

- Issues:
  - [#31](https://github.com/RickHPotter/finance.rb/issues/31)

- Subtasks:
  - Finish the migration away from `HotwireCombobox` and make `RubyUI::Combobox` the
    default solution.
  - Improve duplicate flow into a faster chained workflow for repeated entry.
  - Improve keyboard-first date and datetime input.
  - Improve mobile/PWA date selection so users are not forced into awkward manual
    input.
  - Extend `BulkyBar` so it also communicates useful aggregate information about the
    current selection.
- Extra:
  - Keep new UI work aligned with the current stack: Phlex, Tailwind, Turbo, and Stimulus.

### JIRAIYA-06/app-02: Create `Context` as scenario planning

- Issues:
  - [#32](https://github.com/RickHPotter/finance.rb/issues/32)

- Subtasks:
  - Create a `Context` feature that lets a user simulate financial changes without
    changing the original timeline.
  - Make a context behave like an isolated scenario of the same user, not a separate
    account.
  - Define the initial scope carefully so this does not explode into a full parallel
    application state too early.
- Extra:
  - Treat this as a premium-oriented feature from the beginning, even if the first
    version is intentionally small.

### JIRAIYA-07/fe-03: Create detail dashboards for core finance models

- Issues:
  - [#33](https://github.com/RickHPotter/finance.rb/issues/33)

- Subtasks:
  - Create `:show` screens for `CardTransaction`, `CashTransaction`, and `Budget`.
  - Make these pages behave like dashboards instead of plain record-detail pages.
  - Surface linked installments, exchanges, references, related balances, and useful
    history around the record.
- Extra:
  - Reuse existing Phlex and `ruby_ui` patterns instead of treating these as isolated pages.

### JIRAIYA-08/fe-04: Refine conversations and create a first assistant flow

- Issues:
  - [#34](https://github.com/RickHPotter/finance.rb/issues/34)

- Subtasks:
  - Improve the conversations index so it communicates state more clearly.
  - Refine the conversation screen for better readability and better system-style
    messages.
  - Create a first assistant conversation flow, even if it starts as a guided or
    rule-based helper.
- Extra:
  - Keep the first assistant version narrow: onboarding, reminders, transaction nudges,
    or lightweight guidance are enough.

## CONCLUSION

Sprint 3 should be the sprint that turns the app from “feature-rich and improving” to
“coherent, repeatable, and easier to trust”, while also opening the door to
scenario-based planning and stronger product differentiation.
