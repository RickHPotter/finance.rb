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
  - #[37](https://github.com/RickHPotter/finance.rb/pull/37)

- Subtasks:
  - Treat `Subscription` as a recurring financial transaction concept, such as
    Netflix, ChatGPT, rent, or salary, not as a notification endpoint.
  - Create a built-in category or equivalent convention for subscription-generated
    records.
  - Create a dedicated `Subscription` concept instead of forcing recurrence into
    regular transactions.
  - Support monthly recurrence, fixed-term recurrence, and renewable plans.
  - Allow a subscription to generate either `CardTransaction` or `CashTransaction`.
  - Track enough metadata to explain lifecycle, such as start date, renewal date,
    status, and pause/finish state.
- Extra:
  - [HOMOLOG](https://homolog.30fev.com) deploy.

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
  - Make shared exchange-return paid / not-paid state synchronize across the two users
    through assistant messages instead of remaining local-only.
  - Revisit category assignment so reporting can move from loose category stacking to
    clearer allocation.
- Extra:
  - Keep this part narrow and rule-driven; it is easy for these changes to become too broad.
  - Planning baseline recorded in
    `docs/sprints/3-jiraiya/jiraiya-04/01-financial-safety-rules.md`.
  - Workaround map recorded in
    `docs/sprints/3-jiraiya/jiraiya-04/02-blocked-mutation-workarounds.md`.
  - Implementation order recorded in
    `docs/sprints/3-jiraiya/jiraiya-04/03-implementation-slices.md`.
  - Current implementation status:
    - Slice 1 complete: shared financial safety predicates.
    - Slice 2 complete: domain-level write guards for paid-history rewrites, destroy
      protection, subscription-linked writes, card advances, and exchange-mirror flows.
    - Slice 3 complete: request-level failure behavior with explicit historical-lock
      messages and workaround guidance.
    - Slice 4 complete: exchange-return persistence is normalized to one shared return
      `CashTransaction` with mirrored installments, and shared paid / not-paid state now
      synchronizes bidirectionally through assistant messages, including derived-context
      routing and clear hard failure when the counterpart cannot be resolved.
    - Slice 5 complete: workaround UX now explains the narrow future confirmation
      paths instead of only generic historical-lock guidance.
    - Slice 6 complete: explicit confirmation is now implemented for:
      - paid `CardTransaction` date correction while keeping the same `ref_month_year`
      - paid `CashTransaction` month-boundary correction between adjacent periods during
        delayed-entry cleanup
      - paid `CashTransaction` current-month unpay correction with explicit confirmation
    - Post-slice stabilization complete:
      - maintained suite runner fixed for `.env.test`-based execution
      - indirect projection cleanup fixed for `Investment`, `CARD ADVANCE`, and
        `CashTransactable` aggregate switches
      - unpaid `CardTransaction` moves into paid invoice cycles are now blocked
      - shared paid-state sync resolution now accepts direct reverse linkage
      - shared paid-state notifications now stay pending until explicitly acknowledged
      - mirrored unpaid `EXCHANGE RETURN` structural edits now notify the counterpart
        through a normal actionable assistant update
      - `UserCard` payment-schedule maintenance now updates unpaid exchange-return
        projections correctly across contexts
      - shared-return paid-state sync was further hardened after the first manual pass:
        - counterpart lookup now supports structurally matched legacy/normalized pairs
        - duplicate counterpart families are disambiguated by stable creation order
        - paid-state assistant message deduplication no longer collapses different
          mirrored transactions into one notification
        - mirror sync now runs through Solid Queue with retry on deadlocks from bulk-pay
      - historical standalone `EXCHANGE RETURN` data now has a two-step repair path:
        - first sync standalone `Exchange` rows from legacy mirrored installments
        - then consolidate old one-installment families into one normalized shared return
      - maintained test layers are green:
        `spec/models`, `spec/concerns`, `spec/requests`

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
  - `Context` was completed as the real financial scope of the app, not only as a
    planning concept:
    all planned financial models now belong to `context`, existing records were
    backfilled to `main_context`, and the runtime moved to `current_context`.
  - A clone-based `ContextCloneService` was implemented, together with a tree-style
    contexts UI, context switching, and shared-scope safeguards for scenario
    creation and navigation.
  - Cross-context non-interference was hardened with request/service coverage across
    financial CRUD, recalculation, clone rollback, bulk installment actions, card
    advance, reference merge, imports, backfills, naming conventions, due-payment
    notifications, and stale-form submission after context switching.
  - Query-path and recalculation benchmarking was added so context runtime behavior
    could be compared against `main_context` before rollout.

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
  - Split human chat and assistant/notification traffic into two clear conversation roles:
    one human thread and one shared assistant thread per real-user pair.
  - Turn assistant conversations into an inbox-like flow instead of chat:
    no composer, `Pending` as the default view, and localized `All / Pending` plus
    `Mine / Theirs` filters.
  - Render assistant notifications from structured payloads instead of relying only on
    stored `body`, so the conversation UI can localize and present system events more
    coherently.
  - Refine `conversations#index` and `conversations#show` so assistant messages read as
    assistant-presented while still exposing the human actor behind the action.
- Extra:
  - Historical notification messages were backfilled and redistributed into the new
    conversation model, with `message_notification_v2` becoming the normalized payload
    shape.
  - Audit/apply commands were added so this routing and localization rewrite could be
    reviewed before execution.
  - Exchange Types Added. Loan and Reimbursement, to avoid confusion when creating
    EXCHANGE CashTransactions.
  - Context-aware conversations were completed on top of the assistant-thread refactor:
    conversations now isolate by scenario when the active context is not `main`.
  - `scenario_key` was introduced as the shared scenario identity across users and
    conversations, allowing receiver-side derived contexts to be found or auto-created
    during derived-context notifications.
  - Message replay/apply, pending filtering, unread badges, and assistant action
    rendering were hardened so derived-context message flows do not fall back into
    `main`.
  - Shared exchange-return paid-state changes are also expected to use the assistant
    thread as a bidirectional source of truth between the two users, synchronizing the
    counterpart local record inside the same scenario.
  - A dedicated homolog checklist was added to validate two-user scenario routing,
    receiver auto-cloning, and cross-context non-interference before production rollout.

## CONCLUSION

Sprint 3 should be the sprint that turns the app from “feature-rich and improving” to
“coherent, repeatable, and easier to trust”, while also opening the door to
scenario-based planning and stronger product differentiation.
