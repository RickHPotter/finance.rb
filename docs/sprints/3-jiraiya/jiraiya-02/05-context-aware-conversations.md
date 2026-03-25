# JIRAIYA-08: Context-Aware Conversations

## Outcome Target

Conversations should no longer be purely user-global once the active context is not `main`.

The desired product model is:

1. `main_context`
   - keeps the current shared conversation behavior
   - human and assistant threads behave as they do today

2. derived context
   - conversations are isolated to that scenario
   - messages created in a derived context do not appear in `main`
   - actionable messages created from a derived context must apply only inside a matching derived context

This is an isolation feature, not a lock feature.

## Why Isolation Beats Locking

Locking conversations in derived contexts would reduce engineering work, but it would also break the point of contexts.

A derived context exists so the user can ask:

- what happens if this person pays me later?
- what happens if I split this purchase differently?
- what happens if this exchange is handled another way?

If the assistant/message layer stays tied to `main`, then the user can mutate the financial scenario without seeing the communication and actionable flow that belongs to that scenario.

That would make contexts feel incomplete and misleading.

## New Product Rule

When a user is in a derived context:

- human chat and assistant/system messages must be isolated to that context
- unread state in that context must be isolated too
- applying a message must write into that context only

If a message is sent from user A's derived context to user B, user B should see it only inside a matching derived context.

If user B does not yet have a matching derived context, the app should create it.

## Core Technical Constraint

This only works cleanly if contexts can be matched across users.

Per-user contexts alone are not enough.

Example:

- user A has context `optimistic`
- user B must also receive the message inside the corresponding `optimistic` scenario

Without a shared scenario identity, the app does not know which of user B's derived contexts should receive the message.

## Required Domain Change

Introduce a shared scenario identity between related contexts.

Suggested shape:

- `scenario_key` on `contexts`

Meaning:

- `main_context` stays on the shared default scenario (`scenario_key = nil`)
- derived contexts cloned across users as part of the same scenario share one `scenario_key`

This is the key that allows:

- conversation lookup by scenario
- auto-creation of receiver-side derived contexts
- safe message routing and action replay inside the correct scenario

## Conversation Model Changes

### Conversations

Add:

- `scenario_key`

Result:

- a conversation belongs to one shared scenario identity
- conversation lookup becomes:
  - participants
  - conversation kind (`human` / `assistant`)
  - `scenario_key`

Expected helper evolution:

```ruby
Conversation.find_or_create_human_between!(user_a, user_b, scenario_key:)
Conversation.find_or_create_assistant_between!(user_a, user_b, scenario_key:)
```

### Messages

Messages may not need their own `scenario_key` if they always belong to a conversation.

Preferred V1:

- keep scenario identity on `Conversation`
- derive message scenario from `message.conversation.scenario_key`

Add `messages.scenario_key` only if later querying requires it.

## Receiver Context Resolution

When user A creates a notification in derived context `X` for user B:

1. resolve user A's `scenario_key`
2. try to find user B context with that same `scenario_key`
3. if none exists:
   - create a new derived context for user B
   - clone from user B `main_context`
   - assign the same `scenario_key`
4. route the message into that scenario-scoped conversation

This keeps both users inside the same scenario lineage without leaking into `main`.

## Main Context Compatibility

The current conversation behavior should remain valid in `main_context`.

That means:

- existing human conversation threads stay in main
- existing assistant conversation threads stay in main
- existing unread logic in main remains valid

Derived-context isolation should be additive, not a destructive rewrite of the main experience.

## Actionable Message Rule

If a message belongs to a derived-context conversation:

- create/update/destroy replay must use that conversation context
- actionable checks must use that conversation context
- pending filters must use that conversation context

There must be no fallback from derived context to `main`.

If fallback exists, silent corruption becomes possible again.

## Paid-State Synchronization Rule

Assistant messages are not only for create/update/destroy replay.

For shared exchange-return / borrow-return flows between two users:

- a paid-state change on one side must generate an assistant message
- the counterpart local record on the other side must be updated to the same `paid` / `not paid` state
- the same rule applies in both directions between the two users

This turns the assistant thread into part of the operational source of truth for shared repayment state.

Constraints:

- synchronization must stay inside the active `scenario_key`
- derived-context paid-state changes must not leak into `main`
- if the counterpart mirrored record cannot be resolved safely, the sync must fail clearly instead of mutating only one side

## Migration Strategy

### Slice 1

Add the missing schema:

- `contexts.scenario_key`
- `conversations.scenario_key`

Backfill:

- existing conversations -> `scenario_key = nil`
- existing contexts:
  - main contexts stay `scenario_key = nil`
  - existing derived contexts get unique `scenario_key` values

Status:

- implemented
- `contexts.scenario_key` added
- `conversations.scenario_key` added
- existing/main flows remain on `scenario_key = nil`

### Slice 2

Make conversation lookup context-aware:

- `Conversation.find_or_create_*_between!`
- `ConversationsController`
- unread badge logic
- assistant pending logic

Status:

- implemented
- conversation lists, show routes, message posting, unread badge, and pending filtering are all scoped by `current_context.scenario_key`

### Slice 3

Make friend notifications context-aware:

- notification send uses the sender-side current context
- receiver-side matching context is found or created by `scenario_key`
- messages are written into scenario-scoped assistant conversations

Status:

- implemented
- receiver-side derived context is auto-created from `main_context` when missing
- existing receiver derived context is reused when `scenario_key` already matches

### Slice 4

Make message replay/apply paths context-aware end to end:

- `CashTransactionsController#source_message`
- `CardTransactionsController#source_message`
- message actionability
- applied state
- pending filters

Status:

- implemented
- source-message resolution is scenario-scoped
- assistant action rendering resolves against `current_context`
- message backfill preserves `scenario_key` when rebuilding conversations

### Slice 5

Add hardening coverage:

- derived-context messages never show in `main`
- receiver derived context is auto-created when missing
- applying derived-context messages never mutates `main`
- unread badges and conversation lists stay isolated by context

Status:

- implemented
- hardening coverage now explicitly verifies:
  - unread isolation between `main` and derived scenarios
  - receiver-side derived-context apply after auto-created context routing
  - replay/apply non-interference with `main`

## Current State

All five planned slices are complete.

The conversation runtime now behaves as follows:

- `main_context`
  - stays on the shared default scenario (`scenario_key = nil`)
- derived context
  - gets isolated human and assistant threads
  - gets isolated unread state
  - gets isolated pending/actionable assistant behavior
- cross-user derived notifications
  - route into a shared `scenario_key`
  - auto-create the receiver derived context when needed
  - never fall back into `main`

## Remaining Work

The remaining work is no longer core scoping correctness.

What remains is:

- homolog/manual validation with two real users and multiple derived scenarios
- UX polish around scenario visibility in conversation screens
- optional broader browser-level/system coverage

## Main Risks

1. Duplicate thread explosion
   - if context-aware lookup is wrong, the app can create too many conversations

2. Receiver context mismatch
   - if the wrong receiver context is chosen, actionable messages will mutate the wrong scenario

3. Silent fallback to main
   - this is the most dangerous failure mode

4. Migration ambiguity for old shared assistant conversations
   - existing data must be treated as `main_context` data unless explicitly remapped

## Recommendation

Do not try to patch this through filters alone.

The correct path is:

1. give contexts a shared scenario identity
2. scope conversations to that scenario identity
3. route derived-context notifications into matching derived conversations

Without those three steps, any context-aware conversation behavior will stay fragile.

## Initial Command

The first command in this slice should stay read-only:

```bash
bin/rails runner 'puts({ contexts: Context.count, derived_contexts: Context.where.not(source_context_id: nil).count, conversations: Conversation.count, messages: Message.count }.to_json)'
```

Then inspect the current conversation shape before migration:

```bash
bin/rails runner 'puts Conversation.group(:kind).count.to_json'
```
