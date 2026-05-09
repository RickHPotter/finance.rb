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
  - Linked subscription transactions now receive metadata updates without rewriting
    paid history; when a subscription description changes, the previous transaction
    description is appended to the transaction comment instead of replacing an
    existing comment.
  - Subscription form failures now show the generic create/update failure plus
    concrete validation or history-lock details as separate stacked notifications.

### JIRAIYA-03/fe-01: Rethink datatables, filters, and ordering

- Issues:
  - [#29](https://github.com/RickHPotter/finance.rb/issues/29)

- Subtasks:
  - Rework transaction indexes so ordering can be triggered from the table header.
  - Improve the current filtering model and make it more expressive.
  - Keep common filters simple while leaving room for a more advanced query syntax.

- Shipped outcome:
  - card and cash transaction indexes now use a canonical `sort` + `direction`
    contract while preserving legacy card `order_by` compatibility
  - desktop card/cash month-year groups expose visible sort controls for the
    approved sortable columns, with compact mobile sort controls for PWA layouts
  - common filters were consolidated into the index search form with active-filter
    feedback, clear links, and an explicit `all / paid / pending` paid-state
    control
  - advanced filters now keep blank range values blank and support signed price
    inputs consistently across card and cash
  - table-header and filter-row presentation was standardized across the finance
    index surfaces
  - budget sorting was intentionally deferred; the budget index keeps compact
    filters without sort controls or summary chips
  - modal/data-entry polish shipped with the slice, including which-key support for
    investment and budget forms, transfer dates without a max-date cap, and modal
    autofocus for pay, pay multiple, transfer, and pay-in-advance flows

- Left out intentionally:
  - a free-form query language or reserved parser parameter
  - mixed cash-plus-budget row sorting
  - dedicated budget sorting

- References:
  - [datatables, filters, and ordering planning](docs/sprints/3-jiraiya/jiraiya-03/01-datatables-filters-ordering-planning.md)

### JIRAIYA-04/be-02: Tighten financial safety rules

- Issues:
  - [#30](https://github.com/RickHPotter/finance.rb/issues/30)

- Goal:
  - Make paid-history changes predictable and safe without turning every correction
    into an unsafe bypass.
  - Normalize shared exchange-return flows so both users can rely on the same
    canonical reference chain.

- Shipped outcome:
  - paid-history guards now block unsafe installment, allocation, destroy, card
    advance, subscription, and exchange-mirror rewrites
  - approved historical corrections use explicit confirmation flows instead of
    silent mutation
  - shared exchange-return chains now use canonical immediate-parent references
  - shared paid-state and structural updates now route through assistant messages
    without echo loops
  - linked `BORROW RETURN` rows are destroy-locked while they remain part of a
    shared-return chain
  - Exchange Audit became the operator surface for canonical reference review and
    reached zero pending after rollout cleanup
  - the old rollout migration, legacy repair runners, and naming modal entry flow
    were removed after production cleanup

- Left out intentionally:
  - broad category/entity allocation redesign; the V1 rule remains a hard block once
    paid history exists, except for later explicitly scoped subscription allocation
    behavior

- References:
  - [financial safety rules](docs/sprints/3-jiraiya/jiraiya-04/01-financial-safety-rules.md)
  - [blocked mutation workarounds](docs/sprints/3-jiraiya/jiraiya-04/02-blocked-mutation-workarounds.md)
  - [implementation slices](docs/sprints/3-jiraiya/jiraiya-04/03-implementation-slices.md)

### JIRAIYA-05/fe-02: Consolidate data entry UX

- Issues:
  - [#31](https://github.com/RickHPotter/finance.rb/issues/31)

- Goal:
  - Make daily data entry faster and more consistent without leaving transitional UI
    primitives behind.

- Shipped outcome:
  - `hotwire_combobox` was removed; `RubyUI::Combobox` is now the supported combobox
    path
  - combobox keyboard behavior was tuned for fast tab/shift-tab workflows
  - card, cash, and investment now support chained creation/duplication where scoped
  - chain flows support both “save and finish” and “finish without saving”
  - card/cash transaction forms now use a split date/time input with 24-hour-friendly
    time entry
  - mobile cash/card transaction forms now replace native date/time fields with a
    RubyUI calendar plus a compact clock picker; date changes update installment
    dates, while card date changes still intentionally refresh the form so card
    reference calculations remain correct
  - after a card date refresh, focus is handed to the time control instead of falling
    back to date, category, or entity; on mobile this means the clock hour input is
    selected
  - investment forms now use the same RubyUI calendar on mobile in date-only mode,
    with the calendar taking the full date slot and no clock rendered
  - transaction and investment form submission skeletons were updated so mobile
    loading states match the RubyUI calendar/clock controls instead of the old
    compact native inputs
  - form failure feedback was standardized across subscription, cash/card
    transaction, budget, and investment forms: the generic create/update failure
    appears first, concrete validation or history-lock details stack after it, and
    generic `is invalid` noise is suppressed
  - the shared notification frame now owns fixed positioning so multiple flash cards
    stack with spacing instead of rendering on top of each other
  - payment and transfer modals now use the same shared split date/time control,
    including localized weekday feedback and max-datetime validation with shared
    flash feedback
  - transaction forms now expose an `Esc` quick-jump overlay for keyboard-first
    navigation across the main form fields and chain toggle
  - the bulk action bar now shows selected count, selected total, delayed hide, page
    selection, and shift-range selection
  - Pay/Transfer enablement is computed from selected-row eligibility
  - `Add to Subscription` is available from cash/card indexes and syncs selected
    transactions into the subscription category/entity model
  - partial `PayMultiple` is available for cash installments with a dedicated modal,
    deterministic amount bounds, and explicit partial-installment selection
  - card-bound partial-pay exchange-return flows now preserve the paid prefix and
    only grow the unpaid remainder when later same-bucket source exchanges are added
  - duplicate-mode `EXCHANGE` card transaction cleanup now avoids reviving removed
    payer entities/categories when a duplicated exchange is converted into a regular
    transaction

- Left out intentionally:
  - installments and exchange-specific forms still use their existing date controls
  - `Budget` and `Subscription` duplication were not added

- References:
  - [data entry UX planning](docs/sprints/3-jiraiya/jiraiya-05/01-data-entry-ux-planning.md)
  - [implementation slices](docs/sprints/3-jiraiya/jiraiya-05/02-implementation-slices.md)

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
  - Due-payment reminders were further hardened operationally:
    - reminder selection is explicitly `main_context`-only
    - unpaid reminders are split into overdue, due today, and due tomorrow buckets
    - email digest is now the reliable fallback surface when mobile PWA push delivery
      is inconsistent, especially on iPhone
    - push now sends one high-urgency overdue summary plus per-installment due-today
      pushes
    - rollout is temporarily limited to `User.first` until reminder behavior is
      validated in production

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

- Locked direction:
  - Dashboards are reached through a dedicated `Analyse` action in month-year rows.
  - Description links keep opening `edit`.
  - Dashboards are full-page V1 screens, not modals or sheets.
  - Dashboards may include existing action buttons such as edit, duplicate, pay, and
    destroy, but must keep existing safety rules intact.
  - Implementation starts with `CashTransaction`.

- References:
  - [detail dashboard planning](docs/sprints/3-jiraiya/jiraiya-07/01-detail-dashboard-planning.md)
  - The original scope was cash/card/budget, but the dashboard pattern has since
    expanded into:
    - `user_bank_accounts#show`
    - `user_cards#show`
    - `categories#show`
    - `entities#show`
  - `user_bank_accounts#show` and `user_cards#show` now include interactive
    category-first and entity-first breakdown dashboards with strict `ONLY ...`
    grouping semantics for mixed allocations.
  - `user_cards#show` also includes a read-only reference section with a year
    carousel so only up to 12 references are visible per selected year.
  - `categories#show` and `entities#show` now use pie-chart breakdowns, including a
    shared combobox-style multi-source filter that mixes bank accounts and cards in
    one selector.

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
