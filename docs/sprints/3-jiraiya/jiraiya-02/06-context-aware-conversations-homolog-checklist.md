# JIRAIYA-08: Context-Aware Conversations Homolog Checklist

## Goal

Validate that context-aware conversations behave correctly with real-ish homolog data and two real users.

This checklist is for failure assessment, not only happy-path confirmation.

## Preconditions

1. Homolog is deployed with the current `JIRAIYA-06` and `JIRAIYA-08` changes.
2. Two users exist and can log in independently.
3. Both users have:
   - `main_context`
   - at least one bank account
   - the required built-in categories/entities already present
4. Push/email behavior is either disabled or understood as non-production-safe.

## Core Assertions

The feature should satisfy all of the following:

1. `main_context` conversations stay in `main`.
2. Derived-context conversations stay isolated from `main`.
3. A derived notification to another user auto-creates the receiver derived context when missing.
4. Receiver-side apply/create/update flows mutate only the matching derived context.
5. Unread and `Pending` surfaces are scenario-scoped.
6. No assistant action in a derived scenario should silently act on `main`.

## Test Matrix

### A. Main-to-Main Baseline

1. Log in as `User 1`.
2. Stay in `Main`.
3. Create an exchange transaction involving `User 2`.
4. Log in as `User 2`.
5. Open conversations in `Main`.

Expected:

- notification appears in `Main`
- no new derived context is created for `User 2`
- applying the message changes only `User 2 main_context`

Failure notes:

- If a derived context is created here, scenario routing is too aggressive.
- If the message does not appear in `Main`, main scenario routing is broken.

### B. Derived-to-Derived Auto-Creation

1. Log in as `User 1`.
2. Create or switch to a derived context, for example `Optimistic`.
3. Create an exchange transaction involving `User 2`.
4. Log in as `User 2`.
5. Inspect contexts.
6. Open conversations in `Main`.
7. Switch to the auto-created derived context.
8. Open conversations there.

Expected:

- `User 2` receives a new derived context
- that derived context uses the same scenario lineage
- no derived notification appears in `User 2 main_context`
- the assistant message appears only in the matching derived context

Failure notes:

- If the message appears in `Main`, there is a scenario leak.
- If no receiver context is created, cross-user derived routing is broken.
- If a second unrelated derived context is created instead of reusing the scenario, scenario matching is broken.

### C. Derived Apply Isolation

1. Continue from the previous scenario.
2. While logged in as `User 2`, stay in the auto-created derived context.
3. Apply the assistant message using the UI action.
4. Inspect financial records in:
   - `User 2 derived context`
   - `User 2 main_context`

Expected:

- the transaction is created or updated only in the derived context
- the message becomes applied there
- `User 2 main_context` remains unchanged

Failure notes:

- If `main_context` changes, this is a release blocker.
- If the message stays pending after a successful apply, replay/apply bookkeeping is broken.

### D. Wrong-Scenario Denial

1. While logged in as `User 2`, switch back to `Main`.
2. Try to access the derived conversation message flow from browser history or URL reuse.
3. Try to trigger create/edit/delete from a message belonging to the derived scenario.

Expected:

- the message should not appear in `Main`
- wrong-scenario apply routes should not work
- no main-context mutation should occur

Failure notes:

- If applying by copied URL still works from `Main`, there is a scenario guard failure.

### E. Unread Isolation

1. Create one unread assistant message in `Main`.
2. Create one unread assistant message in a derived context.
3. Observe:
   - hub tab unread state in `Main`
   - hub tab unread state in derived context
   - `conversations#index?filter=unread` in both contexts

Expected:

- `Main` only reflects main unread
- derived context only reflects derived unread
- the lists do not mix scenario messages

Failure notes:

- If counts or lists mix, unread filtering is still user-global somewhere.

### F. Existing Receiver Derived Context Reuse

1. Ensure `User 2` already has a derived context matching the sender scenario.
2. From `User 1`, send another derived-context exchange notification in that same scenario.

Expected:

- no extra receiver derived context is created
- the new message lands in the existing scenario-scoped assistant conversation

Failure notes:

- If a second receiver context is created, reuse-by-`scenario_key` is broken.
- If a second assistant thread appears for the same pair/scenario, conversation lookup is broken.

### G. Main/Derived UI Clarity

1. Open `conversations#index` in `Main`.
2. Open `conversations#index` in a derived context.
3. Open `conversations#show` in both.

Expected:

- scenario badge/header clearly shows whether the user is in `Main` or a derived context
- the footer context switcher highlights the active context consistently

Failure notes:

- If footer state is stale after switching, navigation/global rerender is still inconsistent.
- If the badge shows the wrong scenario, `current_context` rendering is wrong.

## Performance Watch

Current behavior is synchronous:

- sender creates derived-context exchange
- receiver derived context may be cloned inline
- assistant message is created in the same request flow

Observe during homolog:

1. First derived cross-user exchange when receiver has no matching context.
2. Repeated derived exchange when receiver context already exists.

Expected:

- first request is slower than reuse, but still acceptable
- repeated requests should be noticeably lighter

Failure notes:

- If first-time creation is too slow, move receiver context provisioning + message routing into a job later.

## Release Blockers

Treat any of the following as blockers:

1. Derived message appears in `Main`.
2. Applying derived message mutates `main_context`.
3. Receiver derived context is not created or the wrong one is chosen.
4. A second assistant thread is created for the same pair and same scenario.
5. Unread or `Pending` mixes messages across scenarios.

## Suggested Commands

Read-only inspection helpers:

```bash
bin/rails runner 'puts Context.order(:user_id, :id).pluck(:id, :user_id, :name, :main, :scenario_key, :source_context_id).map { |row| row.join(\" | \") }'
```

```bash
bin/rails runner 'puts Conversation.order(:id).pluck(:id, :kind, :scenario_key).map { |row| row.join(\" | \") }'
```

```bash
bin/rails runner 'puts Message.order(:id).last(20).map { |m| [m.id, m.conversation_id, m.user_id, m.body, m.applied_at].join(\" | \") }'
```

## Result Recording

For each failed step, record:

1. active user
2. active context
3. conversation id
4. message id
5. expected behavior
6. actual behavior
7. whether `main_context` was touched incorrectly
