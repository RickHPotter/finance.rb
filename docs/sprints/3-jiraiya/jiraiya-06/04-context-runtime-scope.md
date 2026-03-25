# JIRAIYA-06 Slice 3: Runtime Context Scope

## Goal

Finish the behavioral migration from user-global financial access to
`current_context` for the core runtime flows.

## Delivered

### Application Layer

- `current_context` resolution in `ApplicationController`
- session-backed context persistence
- fallback to `current_user.main_context`
- explicit context switching route and controller
- minimal context switcher UI in the app footer

### Controllers Migrated

- `CashTransactionsController`
- `CardTransactionsController`
- `BudgetsController`
- `InvestmentsController`
- `SubscriptionsController`
- `ReferencesController`
- `CashInstallmentsController`
- `BalancesController`

## Services Migrated

- cash transaction finders
- cash installment finders
- card installment finders
- budget finders
- investment finders
- reference merge service
- balance finder JSON services
- `Logic::RecalculateBalancesService`

## Model/Callback Migration

The runtime slice also moved context propagation into the cross-model flows that
still create or update financial records indirectly:

- card payment flows
- card advance flows
- subscription-linked transaction sync
- budget remaining value calculations
- reference generation and invoice lookup
- grouped cash-transaction attachment through `CashTransactable`
- exchange-generated cash transactions

## Validation

The migrated request surface passed with:

- `spec/requests/contexts_spec.rb`
- `spec/requests/cash_transactions_spec.rb`
- `spec/requests/card_transactions_spec.rb`
- `spec/requests/budgets_spec.rb`
- `spec/requests/investments_spec.rb`
- `spec/requests/subscriptions_spec.rb`
- `spec/requests/references_spec.rb`

Result:

- `47 examples, 0 failures`

## Boundary

Slice 3 makes the core financial runtime context-aware.

It does not yet include:

- cloning a context
- comparison/dashboard between contexts
- non-core maintenance/admin scans that still read by `user`

Those belong to the next slices.
