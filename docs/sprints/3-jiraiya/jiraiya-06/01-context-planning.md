# JIRAIYA-06 Planning: Context As Scenario Planning

## Main Idea

`Context` should behave as a scenario-bound financial timeline for one user.
It is not a second account and it is not a lightweight filter. It is a full planning
workspace where the user can ask:

- what happens if I cancel some subscriptions?
- what happens if I buy a car?
- what happens if I move my salary, rent, or investments?

The current direction is clone-based, not overlay-based.

## Product Direction

Each user has:

- many `contexts`
- one mandatory main context

The main context is the real timeline. Additional contexts are scenario timelines
derived from an existing context and then edited independently.

The models that should become context-scoped are:

- `CashTransaction`
- `CardTransaction`
- `Budget`
- `Investment`
- `Subscription`
- `Reference`

Everything else remains primarily user-scoped:

- `Category`
- `Entity`
- `UserCard`
- `UserBankAccount`
- conversation/chat domain
- notification/push domain

The database should remain a single PostgreSQL database.
Do not introduce SQLite and do not introduce one database per context.

Reason:

- the financial domain needs one coherent source of truth
- foreign keys and associations stay much simpler in one database
- comparing main context against scenario contexts remains straightforward
- the real problem is scope and recalculation, not storage engine choice

## Scope Decision

`Context` should become mandatory financial scope immediately.
Do not introduce a temporary abstraction like `current_financial_scope`.

Use:

- `current_user` for auth, ownership, and shared structural records
- `current_context` for anything financial

This is the easier path for this app because:

- there are only two users
- a clean break is easier to reason about than a long transitional layer
- old code that still incorrectly scopes by `user` becomes easier to spot
- recalculation and planning rules stay conceptually cleaner

## Why Clone-Based Contexts Make Sense

For this app, clone-based contexts have one strong advantage: the query model stays
simple.

Instead of constantly calculating:

- real data
- plus scenario deltas
- minus disabled records
- plus temporary overrides

the app can query one context directly and treat it as a coherent financial world.
That is easier to reason about in:

- balances
- projections
- datatables
- dashboards
- transaction history

Given the small number of users, database size and copy duration are acceptable
tradeoffs if the resulting domain stays clearer.

## Proposed Domain Shape

### Context

Expected first fields:

- `user_id`
- `name`
- `description`
- `kind` or `main`
- `source_context_id` for derived contexts
- `cloned_at`
- `archived_at`

Main behavior:

- one user must always have one main context
- all context-scoped records belong to exactly one context
- a new non-main context is created by cloning an existing context

### Context-scoped records

The following records should gain `belongs_to :context`:

- `CashTransaction`
- `CardTransaction`
- `Budget`
- `Investment`
- `Subscription`
- `Reference`

And `User` should reach them mostly through contexts, not directly as its primary
mental model anymore.

## Cloning Semantics

When a new context is created from another context:

1. create the target context
2. copy all context-scoped records from source to target
3. preserve references to user-scoped records:
   - same `category_id`
   - same `entity_id`
   - same `user_card_id`
   - same `user_bank_account_id`
4. treat copied records as independent records from that point on

This means:

- editing a copied transaction affects only the target context
- deleting a copied investment affects only the target context
- creating a new subscription inside a scenario affects only that scenario
- editing a copied reference affects only the target context

That is the clearest mental model for the user.

## What Should Not Be Cloned

These should remain shared at user level in V1:

- categories
- entities
- cards
- bank accounts

Reason:

- they are structural inputs of the user domain
- cloning them would multiply low-value records
- it would make forms and foreign keys much harder to manage

Contexts should change financial decisions, not duplicate the user’s entire setup.

## Main Technical Concern

The clone approach solves querying, but it moves complexity into lifecycle and
consistency.

The hard question is not creation. Creation is straightforward.
The hard parts are:

- what happens after the copy
- how copied records are traced
- how recalculation behaves per context
- how much lineage between source and copy should still exist

## Recommended Lineage Strategy

Do not try to keep copied records live-synced.

Instead, store only light lineage metadata:

- `source_context_id` on `Context`
- optional `source_record_id` and `source_record_type` on copied records, only for audit/debug

But once copied:

- no automatic back-propagation
- no automatic forward-propagation
- no partial merge system in V1

This is important. The moment you try to “keep clones somewhat synchronized,” the
model becomes much harder than either pure clone or pure overlay.

## Possible Problems With The Clone Approach

### 1. Copy operations can be heavy

If a context has years of transactions, budgets, investments, and subscriptions,
cloning may take noticeable time.

This is acceptable for this app, but it still implies:

- background job or explicit progress feedback may be needed
- cloning should probably be transactional per batch, not one giant memory copy

### 2. Recalculation must become context-aware everywhere

Any balance recalculation logic that currently works off `user` alone will likely be
wrong once multiple contexts exist.

This is probably the biggest engineering risk.

Anything that now assumes:

- “all user transactions”

will need to become:

- “all user transactions for this context”

This touches:

- balance services
- reference logic
- installments
- card payment flows
- exchanges
- budgets
- dashboards and finders

Concrete hotspots already visible in this codebase:

- `Logic::RecalculateBalancesService`
- `Logic::RecalculateCountAndTotalService`
- `CardTransaction#build_month_year`
- `CashTransaction#build_month_year`
- `Reference` callbacks that trigger recalculation
- `UserCard#calculate_reference_date`

### 3. Main-context assumptions may be scattered through the app

Today many queries probably assume there is only one financial world per user.
Contexts will expose every hidden assumption of that kind.

Typical failures:

- `current_user.cash_transactions`
- `current_user.card_transactions`
- `current_user.budgets`
- `current_user.references`
- service objects that accept only `user`

Those APIs should move to a new center of gravity around `context`.

### 4. References may become tricky

References should now be treated as context-scoped too.
That is the correct direction if a context is supposed to answer questions like:

- what if I change the due date?
- what if I change the closing date logic?
- what if this card cycle moved?

That means the app must separate:

- shared card structure (`UserCard`)
- context-owned cycle instances (`Reference`)

This is subtle but important:

- `UserCard` can stay shared
- `Reference` should be scenario-owned
- reference generation and transaction month/year logic must read the current context

### 5. Destroy/edit logic is simpler for records, harder for provenance

Destroying a copied transaction is easy if it is truly independent.
What gets harder is explaining provenance:

- where did this copied record come from?
- should the UI show that it was cloned?
- should the user be able to “reset to source” later?

If provenance is shown, it should be read-only in V1.

### 6. Cross-context reporting can become expensive later

Single-context queries are cleaner with cloning.
But if later you want to compare:

- main context vs scenario A vs scenario B

you may need dedicated comparison services, because now each context has full copies
instead of lightweight deltas.

This is acceptable, but worth acknowledging early.

## Recommended V1 Constraints

To keep the clone approach under control:

- only clone from one existing context into a new one
- no re-sync after clone
- no merge-back into source context
- no nested context trees deeper than needed
- no cloning of user-scoped setup records
- no context-specific categories/entities/cards/accounts in V1

## Suggested Build Order

### Slice 1: Introduce `Context`

- create model, associations, validations
- ensure every user has one main context

Status:

- done
- recorded in `02-context-foundation.md`

### Slice 2: Add `context_id` to financial models

- `cash_transactions`
- `card_transactions`
- `budgets`
- `investments`
- `subscriptions`
- `references`

Backfill rule:

- create the main context for every user first
- assign all existing financial records to that user’s main context
- only then make `context_id` required

Status:

- done
- recorded in `03-context-financial-model-backfill.md`

### Slice 3: Make calculations context-aware

- finder services
- balance services
- dashboards
- any callback or recalculation path that assumes user-global data

Migration rule:

- do not add a temporary scope abstraction
- move directly from user-scoped financial access to context-scoped financial access
- let failures surface explicitly until all financial entry points are moved

Likely first breakpoints:

- `ApplicationController#check_reasoning`
- `CashInstallmentsController` recalc actions
- `CardTransaction` and `CashTransaction` create/update/destroy flows
- `BudgetsController` and `InvestmentsController` min/max range queries
- `NamingConventionsController` transaction scan
- any finder using `current_user.cash_transactions` or `current_user.card_transactions`

Status:

- done for the core runtime financial surface
- recorded in `04-context-runtime-scope.md`
- completed with:
  - `current_context` in the application layer
  - session-backed context switching
  - context-aware cash/card/budget/investment/subscription/reference controllers
  - context-aware balance and finder services
  - context propagation in cross-model financial callbacks

### Slice 4: Build cloning service

- clone one context into another
- preserve links to shared user-scoped records
- optionally store source lineage

Recommended cloning order:

1. context
2. references
3. budgets
4. subscriptions
5. cash transactions
6. card transactions
7. investments

This order is not final, but it reflects the idea that cycle/reference state should
exist before cloned transaction flows are recalculated inside the new context.

Status:

- done
- completed with:
  - `Logic::ContextCloneService`
  - context-scoped reference uniqueness
  - clone rollback protection
  - clone fidelity coverage for linked financial graphs
- recorded in `05-context-cloning-and-hardening.md`

### Slice 5: Add context switching UX

- select current context
- clearly indicate when user is outside main context
- make controllers that operate on financial records require a resolved `current_context`

Status:

- done for the first shipping UX
- completed with:
  - footer context switcher
  - tree-style contexts index/show/new flow
  - scenario badges on conversations and balances
  - stale-form protection when context changes after a form is opened
- recorded in `05-context-cloning-and-hardening.md`

### Slice 6: Harden cross-context isolation

- prove that creates, updates, destroys, and recalculations in one context do not
  mutate another
- prove clone failures roll back cleanly
- audit remaining `user`-scoped financial paths and either migrate them or make
  their `main_context` rule explicit

Status:

- done
- completed with:
  - request isolation coverage across all planned financial models
  - side-effect coverage for recalculation, budget remaining value, bulk actions,
    `CARD ADVANCE`, reference merge, and message replay/apply
  - import/backfill/notifier/naming-convention hardening
  - benchmark tooling for context runtime comparison
- recorded in `06-context-isolation-and-operational-hardening.md`

### Slice 7: Add scenario dashboard

- compare selected context against main context
- surface delta in balance, subscriptions, budgets, and key obligations

## Recommendation

The clone-based approach is defensible and likely the better long-term model for this
app, but only if the app commits fully to `context` as the financial scope.

The biggest risk is not copy time. The biggest risk is half-migrating the domain,
where some services still think in `user` and others think in `context`.

So the real planning rule should be:

- if `Context` is introduced, it must become the primary financial scope everywhere
  that affects balances, transaction listing, and planning

And specifically for this app:

- `Reference` must follow the same path as transactions, budgets, investments, and
  subscriptions, otherwise one of the strongest scenario-planning levers remains
  global and the feature becomes weaker than intended.

- the app should prefer a hard cut to `current_context` over a long transitional
  abstraction layer.

That is the part worth taking seriously before development starts.
