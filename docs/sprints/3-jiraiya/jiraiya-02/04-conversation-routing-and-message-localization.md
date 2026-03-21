# JIRAIYA-08: Conversation Routing and Message Localization

## Goal

The current `conversations` route is acting as if it were a single generic chat, but the product meaning has already diverged.

With the current two-user setup, we now need three distinct conversation threads:

1. `Rikki <-> Gigi`
   - human-to-human conversation
   - should hold the organic chat history
   - this is also where most old messages currently live

2. `Rikki <-> Gigi's Assistant`
   - system-side notifications that affect Rikki
   - transaction-reference messages sent on behalf of Gigi should live here

3. `Gigi <-> Rikki's Assistant`
   - system-side notifications that affect Gigi
   - transaction-reference messages sent on behalf of Rikki should live here

The second goal is to stop localizing notification messages at creation time with the receiver locale in an ad hoc way. That works superficially, but it makes the stored message body feel impure and ties persisted content to transient locale assumptions.

## Problem Statement

### Conversation meaning is overloaded

Today, human chat and transaction/system notifications are mixed in the same conversation space.

That causes a few problems:

- the route name says `conversations`, but the product behavior is closer to a single catch-all `conversation`
- user-to-user chat and assistant/system notifications are not cleanly separated
- future assistant workflows will be harder to reason about if they continue sharing the same thread as human messages

### Message localization is happening too early

Today, notification bodies are written in the language of the receiver at creation time.

That creates these issues:

- persisted content depends on the receiver locale at the exact time of creation
- the body becomes hard to reinterpret if locale preferences change later
- backfills and replay logic become harder because the domain payload and the rendered message are mixed together

## Target Model

### Conversation split

We should model conversations by role, not just by participant count.

Suggested roles:

- `human`
- `assistant`

Suggested participant patterns:

- `human`: exactly the two real users
- `assistant`: one real user plus one assistant identity representing the other side

This means notifications should stop being written into the direct human thread once the assistant split is introduced.

### Message rendering split

Persist notification messages as domain events plus payload, and render localized text from those domain values.

In practical terms:

- `headers` should remain the structured payload for transaction replay
- notification messages should gain an explicit event type or message kind
- the stored `body` should stop being the only source of truth for notification meaning
- localized body text should be derived from message kind + payload + current locale

## Backfill Notes

### Conversation backfill

Historical messages need to be redistributed into the new assistant conversations.

We already have the real discriminator in the current message UI flow:

- `headers.present?` => system transaction notification (`create` / `update`)
- `headers.blank? && reference_transactable.present?` => system destroy notification
- `headers.blank? && reference_transactable.blank?` => human chat

So a naive rule of "no headers means human conversation" is wrong, but the current UI rule is strong enough to backfill the entire `messages` table safely.

When backfilling, we should classify every row into one of:

- `human`
- `transaction_notification`
- `transaction_destroy_notification`

That classification can then drive the assistant conversation split without guessing from free text.

### Localization backfill

We should not blindly rewrite all historical message bodies first.

Safer order:

1. classify message kinds
2. split conversations
3. introduce render-time localization for new notifications
4. decide whether old bodies should remain frozen or be regenerated

## Proposed Development Order

1. Codify message classification in the `Message` model itself.
2. Add a read-only audit/export over the entire `messages` table.
3. Add assistant conversation support.
4. Route new notification messages into assistant conversations.
5. Keep human chat in the direct user conversation only.
6. Introduce explicit notification message kinds.
7. Move notification localization to render time instead of creation time.
8. Backfill messages into the correct conversation buckets.
9. Revisit historical localized bodies and decide whether they stay frozen or are regenerated.

## Open Questions

1. Should assistant identities be explicit persisted records, or implicit conversation roles?
2. Should the old `body` remain stored for notifications, or become a cached/rendered field?
3. Should destroy notifications keep `headers` empty, or should they also gain a structured payload in the new model?
4. Should human and assistant threads share the same UI surface with filters/tabs, or become visibly separate entry points?

## Recommendation

Do this in two phases:

### Phase 1

- split conversations
- route new system notifications into assistant threads
- keep current localized body generation temporarily

### Phase 2

- introduce explicit notification message kinds
- shift notification localization to render time
- backfill historical data with clearer semantics

This keeps the conversation split independent from the larger localization refactor, while still acknowledging that the two concerns are connected.
