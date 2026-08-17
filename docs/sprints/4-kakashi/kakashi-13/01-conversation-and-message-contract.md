# KAKASHI-13 Conversation and Message Contract

## Purpose

KAKASHI-13 rebuilds conversations on top of the explicit `Friendship` identity added
in KAKASHI-12. It replaces participant-ID trust, entity-name lookup, and best-effort
thread creation with one friendship-authorized, scenario-aware conversation contract.

The work preserves existing human messages, actionable-message payloads, supersession
chains, and financial audit evidence. It does not redesign transaction exchange rules.

## Actionable-Message Compatibility Invariant

KAKASHI-13 must not change the business rules that decide whether an actionable
message is sent, who receives it, which transaction/event it represents, which payload
is produced, whether it supersedes another message, or whether it qualifies for
automatic application.

That invariant covers, without limitation:

- create, update, destroy, paid-state, transfer, partial-payment, category,
  exchange-type, loan, reimbursement, and shared-return notification behavior;
- sender and recipient selection;
- main/derived scenario selection already performed by each producer;
- local-reference and transaction-chain resolution;
- payload version, action, category, installment, entity, exchange, reference, and
  intent data;
- supersession selection and propagation;
- existing safety gates for manual apply, automatic apply, destroy, and revert; and
- the timing/order of financial mutation relative to message creation.

Moving producers to a canonical conversation resolver is an infrastructure refactor.
For identical domain inputs, it must emit the same message—or no message—with the same
recipient, payload, references, and application outcome as before. Friendship
authorization introduced by KAKASHI-12 remains in force; KAKASHI-13 does not tighten,
loosen, or reinterpret it.

Before any producer or apply service is refactored, focused characterization coverage
must capture its current behavior. A deliberate business-rule change requires a
separately documented reason, an explicit product decision, and regression coverage;
it must not be hidden inside conversation migration, cleanup, or state-machine work.

## Current-State Findings

The repository already distinguishes `human` and `assistant` conversations and scopes
them with `scenario_key`, but the following gaps make that behavior unsafe or
nondeterministic:

- `POST /conversations` accepts nested participant user IDs and creates a conversation
  without proving an accepted friendship.
- `find_or_create_*_between!` performs a query followed by inserts without a database
  uniqueness constraint, so concurrent callers can create duplicate threads.
- `Conversation.for_users` proves that requested users participate, but does not prove
  that they are the only participants.
- conversations have enumerable numeric URLs and are not linked to the canonical
  friendship row.
- participant rows have no uniqueness constraint and carry none of the participant-
  local archive or mute state.
- avatars still fall back through user-backed entities even though profiles now own
  public identity.
- message kind and actionable state are inferred repeatedly from `headers`, references,
  and timestamps.
- one mutable `Message#audit_operation_id` cannot represent delivery, manual apply,
  automatic apply, rejection, failure, and revert as separate events.
- lists are loaded in full and sorted in Ruby; message streams are also unpaginated.
- broadcasts subscribe to a conversation model stream without making the authorization
  and revoked-friendship boundary explicit.

These findings define the migration seams. Existing behavior that is already correct,
including scenario isolation and versioned actionable payloads, remains part of the
contract.

## Canonical Conversation Identity

A conversation belongs to exactly one `Friendship`, has exactly two participants, and
has one string-backed kind:

- `human`: ordinary user-authored direct messages
- `assistant`: actionable and informational transaction messages

There is at most one conversation for each tuple:

```text
(friendship_id, kind, scenario_key)
```

`scenario_key = NULL` is the main-context scope. A partial unique index covers the main
scope and a second unique index covers non-null scenario keys. Application validation
is explanatory; the database indexes are authoritative under concurrency.

Each conversation receives an immutable UUID `public_id`, and routes resolve only that
identifier. Numeric IDs remain internal foreign keys. The conversation keeps its
`friendship_id` even when the friendship becomes removed or blocked so history and
audits retain their original relationship identity.

All creation and lookup goes through one resolver. The resolver:

1. resolves the canonical friendship for the two users;
2. requires `accepted` state;
3. validates that the requested scenario exists for both users, using `nil` for both
   users' main contexts and the shared `scenario_key` for derived contexts;
4. creates or retrieves the unique conversation and its two participant rows in one
   transaction;
5. handles a uniqueness race by loading the winner rather than returning an error.

Controllers and notification producers do not construct conversations or participant
rows directly.

For actionable producers, replacing direct conversation construction is the only
authorized behavior change in this boundary: conversation identity becomes canonical,
while send/no-send and message content remain equivalent.

## Friendship Authorization and Retention

An accepted friendship is required to:

- create or resolve a conversation;
- list or show it;
- send a human message;
- deliver a new actionable message;
- subscribe to its realtime stream; and
- apply, reject, acknowledge, or revert an actionable message.

When a friendship becomes `blocked`, `removed`, `rejected`, or `pending`, access is
revoked immediately for both users. The conversations, messages, payloads, participant
state, and audit links remain stored but disappear from ordinary routes, counts, and
broadcast authorization. Re-accepting the same canonical friendship restores the same
conversation identities rather than creating replacements.

Revocation does not delete financial messages and does not reverse previously applied
financial operations. A block/unfriend transition may prevent a pending action from
being applied, but financial correction remains an explicit audit/rollback concern.

## Participant-Local State

`ConversationParticipant` is the per-user state boundary. It has a unique
`[conversation_id, user_id]` key and stores:

- `archived_at`
- `muted_at`
- `last_read_message_id`

Archiving hides a conversation only for that participant. A new message from the other
participant clears the recipient's archive so an active conversation cannot remain
silently hidden. Sending a message also makes the sender's copy active. Unarchiving is
explicitly available even when no new message exists.

Muting suppresses email, push, and future attention notifications for that participant.
It does not suppress delivery, realtime rendering, unread counts, or actionable-message
state. Financial messages cannot be deleted through archive or mute controls.

`last_read_message_id` provides participant-scoped read progress. Existing
`messages.read_at` is retained during migration for compatibility and historical
timestamps, then becomes a derived/legacy field rather than the source of unread truth.
A message is unread for a participant when it is authored by the other user and is
newer than that participant's read cursor. Superseded messages do not independently
inflate unread counts.

## Message Kinds and Action States

Every message has an explicit string-backed `kind`:

- `human`
- `transaction_notification`
- `transaction_destroy_notification`
- `paid_state_sync`

Existing rows are backfilled through the current `Message#backfill_kind` behavior.
After backfill, rendering and authorization use the persisted kind; payload inspection
remains a compatibility check, not the classifier.

Actionable messages have one explicit string-backed `action_state`:

- `pending`
- `accepted`
- `rejected`
- `expired`
- `failed`
- `unavailable`
- `reverted`

Human messages have no action state. Paid-state sync messages start `pending` and move
to `accepted` when acknowledged. Transaction create/update/destroy messages start
`pending`; a successful manual or automatic application moves them to `accepted`.
`auto_applied` records provenance, not state.

Definitions:

- `rejected`: the recipient deliberately declined a still-valid pending action.
- `expired`: a newer message superseded it before application.
- `failed`: the latest apply attempt failed validation or persistence and may be
  retried while its immutable preconditions still match.
- `unavailable`: friendship, context, source, local reference, or payload conditions no
  longer permit application.
- `reverted`: an accepted application was successfully rolled back.

Legacy timestamps (`applied_at`, `reverted_at`, `read_at`) remain useful audit and
display facts. They do not replace the explicit state machine.

## Action Application Contract

Manual and automatic application may call the same idempotent orchestration service.
This consolidation is permitted only after parity coverage proves that every existing
eligibility, validation, mutation, and failure branch is preserved. The business-rule
difference remains exactly what it is today: initiator (`manual` or `automatic`) and
the existing recipient friendship-policy gate.

The service locks the message and validates, inside one database transaction:

- the viewer is the recipient and still belongs to an accepted friendship;
- the conversation and target context share the exact scenario key;
- the message is current, pending, and not superseded;
- the payload version and action are supported;
- the source identity and expected local reference resolve inside the recipient's
  context;
- the local reference still matches the payload's captured precondition/fingerprint;
- destructive or paid-history rules allow the requested mutation; and
- no prior successful action event exists for this message and effect.

Duplicate delivery or a repeated request returns the existing result without applying
the financial mutation twice. Stale or ambiguous references move the message to
`unavailable`; validation/persistence errors move it to `failed` and retain a safe,
localized error summary. Raw exception text is logged, not exposed.

Reject and acknowledge are also idempotent state transitions. Revert continues to use
the guarded KAKASHI-08 rollback path and is offered only while its operation remains
revertible and the message has not been superseded in either participant's assistant
thread.

## Immutable Action Event Ledger

Every actionable transition creates a `MessageAction` (name may be adjusted to match
the final model namespace) with:

- message, conversation, friendship, and actor IDs;
- recipient context ID and scenario key;
- action (`apply`, `reject`, `acknowledge`, `revert`);
- initiator (`manual`, `automatic`, `system`);
- outcome (`succeeded`, `failed`, `denied`, `idempotent`);
- resulting action state;
- linked `AuditOperation`, when a financial mutation occurred;
- a bounded error code and metadata; and
- timestamps.

The ledger is append-only. `Message#action_state` is the current projection used by the
UI. Message creation retains the originating transaction operation as a separate link;
an apply or revert never overwrites it.

## Scenario and Context Contract

The selected context is always visible on conversation index/show pages. Main-context
conversations use a nil scenario key; a derived conversation requires the exact shared
scenario key. There is no fallback from a missing derived context to `main_context`.

If either participant lacks the requested scenario, conversation creation and new
actionable delivery fail closed. Existing history remains retained but unavailable in
that missing context until the scenario mapping is restored.

Every local transaction link is resolved in the current recipient context at render
time and authorized again by the destination controller. Payload IDs are not accepted
as proof of local ownership.

## Conversation Experience

The new-conversation entry lists accepted friendships, using `UserProfile#display_name`
and the attached profile avatar with the shared fallback. It never accepts a raw user
ID from the browser. Selecting a friend resolves the canonical `human` conversation
for the current scenario and redirects to its public URL.

The index provides active, unread, human, assistant, archived, and muted views. Each
row includes profile identity, kind, scenario, unread count, last-message preview, and
last activity. Ordering is deterministic by `last_message_at DESC, id DESC`; empty
conversations use `created_at` as activity. Archive and mute state never changes that
canonical activity order.

Conversation show provides:

- an explicit back link to the conversation list;
- participant profile identity and selected scenario;
- archive, unarchive, mute, and unmute controls;
- an empty state for a human thread with no messages;
- links from actionable messages to the local transaction when available; and
- a return-to-conversation parameter on transaction links.

Assistant threads do not expose the human composer. Human threads never accept
actionable payload fields from the browser.

## Pagination and Realtime Delivery

Conversation and message pagination use stable cursor/keyset ordering rather than
offsets:

- conversations: `(last_message_at, id)` descending;
- messages: `(created_at, id)` descending for retrieval, reversed to chronological
  order for rendering.

The first message page contains the newest messages. Loading older messages prepends
them without changing the URL's conversation identity or the read cursor. A bounded
page size is enforced server-side.

Realtime broadcasts append only newly committed messages to currently authorized
participants. The client deduplicates by stable message DOM ID. A friendship state
change revokes future stream authorization; a stale browser receiving no further data
still cannot call any conversation or message endpoint.

## Migration and Backfill

The migration is additive and deploy-safe:

1. add public/canonical identity and participant-state columns without new non-null
   constraints;
2. classify messages and populate action-state projections from existing timestamps,
   supersession, and payloads;
3. map each two-user conversation to the canonical friendship, creating a retained
   friendship only through the KAKASHI-12 reconciliation path where historical data
   proves the relationship;
4. inventory malformed conversations (zero, one, duplicate, or more than two
   participants), duplicate canonical threads, missing scenarios, and invalid payloads;
5. merge duplicate thread messages deterministically into the oldest canonical
   conversation while preserving message IDs, supersession, references, and audit
   links;
6. add unique indexes, foreign keys, and non-null constraints after verification; and
7. switch routes and producers to the canonical resolver before removing direct nested
   participant creation.

Ambiguous historical rows are reported and left untouched for operator correction;
the migration must not guess a friendship or discard a message.

## Explicitly Out of Scope

- group conversations or friendships with more than two users
- message editing or deletion
- files, reactions, typing indicators, or presence claims
- end-to-end encryption
- full-text message search
- changing transaction exchange, replay, or rollback financial semantics
- changing when actionable messages are sent, received, superseded, auto-applied, or
  considered safe
- deleting history when a friendship changes state
- notification-channel redesign beyond honoring participant mute state
