# JIRAIYA-08: Conversation Routing and Message Localization

## Outcome

The conversations/messages refactor is now in place:

- human chat and notification traffic are split
- notification messages use `message_notification_v2`
- notification text is rendered from structured payloads instead of relying only on stored `body`
- historical notification messages have been backfilled
- assistant conversations are merged to one shared thread per real-user pair
- assistant threads have no composer
- assistant messages are assistant-presented in the UI while still exposing the human actor
- assistant threads default to `Pending`
- assistant threads support localized `All / Pending` and `Mine / Theirs` bubble filters

The resulting conversation model is:

1. `User A <-> User B`
   - human-to-human conversation
   - organic chat history only

2. `User A <-> User B Assistant`
   - one shared assistant/system conversation for that pair
   - transaction notifications and other assistant-side operational messages in both directions

## Original Problem

The original assistant-thread model was too granular.

Between the same two users, the app could expose:

- one human conversation
- one assistant thread "for me"
- one assistant thread "for them"

That created avoidable cognitive overhead:

- users had to reason about "my assistant" versus "their assistant"
- assistant-presented message styling alone did not solve the thread-level confusion
- the product intent was simpler than the data model

There was also a UX mismatch:

- assistant threads still behaved too much like chat
- the composer existed where sending a human message made no sense
- applied messages could bury the still-actionable ones

## Final Model

### Conversation Roles

- `human`
- `assistant`

### Participant Rules

- `human`: exactly the two real users
- `assistant`: the same two real users, but representing the shared system/assistant thread for that pair

This means there are exactly two conversations per pair:

- one human thread
- one assistant thread

There is no longer any product-level distinction based on `assistant_owner`.

### Assistant Thread UX

Assistant conversations now behave like an inbox:

- no composer in `conversations#show` when `conversation.assistant?`
- assistant messages are presented as assistant-authored bubbles
- the human actor is still visible as metadata
- messages are visually split between `Mine` and `Theirs`
- `Pending` is the default view
- `Pending` is based on actionable state, not just raw `applied_at`
- `All` is available when full history is needed

### Message Rendering

This part is implemented and should be preserved:

- `headers` remain the structured payload for replay
- notification messages use an explicit v2 payload shape
- the stored `body` is no longer the only source of truth for notification meaning
- localized notification text is derived from payload + current locale

## Backfill Notes

### Message Classification

The message classification used for the backfill remains:

- `headers.present?` => transaction notification
- `headers.blank? && reference_transactable.present?` => destroy notification
- `headers.blank? && reference_transactable.blank?` => human chat

That rule is enough to separate human versus assistant traffic without guessing from free text.

### Conversation Backfill

Historical messages were first redistributed into assistant conversations, then merged out of the older assistant-owner shape into the new shared assistant thread per pair.

The merge rule was:

- for each real user pair
- keep the `human` conversation as-is
- collapse all assistant messages into one shared `assistant` conversation

## Remaining Questions

1. Should applied assistant messages eventually get their own explicit `Applied` filter, or is `All` enough?
2. Should obsolete assistant conversations from the old model be deleted immediately or kept temporarily for safety/debugging?
3. Should assistant filters remain URL-only, or later be remembered per user/session?

## Result

This slice is complete:

- assistant routing is merged to one thread per user pair
- assistant-presented message UI is in place
- assistant-thread composer is removed
- assistant threads are pending-first by default
- assistant filters are localized and mobile-safe

The product model is now simple:

- one place for human chat
- one place for assistant/system work

## Initial Command

The first command in this slice should stay read-only:

```bash
bin/rails message_backfill:audit OUTPUT=tmp/message_backfill_audit.json
```

After the audit is reviewed, apply the redistribution and localization rewrite in dry-run mode first:

```bash
bin/rails message_backfill:apply DRY_RUN=true OUTPUT=tmp/message_backfill_apply.json
```

Then run the same command without dry-run:

```bash
bin/rails message_backfill:apply DRY_RUN=false OUTPUT=tmp/message_backfill_apply.json
```
