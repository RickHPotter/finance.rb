# KAKASHI-13 Implementation Slices

## Delivery Rules

- Complete slices in order and keep migrations compatible with mixed-version deploys.
- Preserve all human and financial messages, supersession chains, references, and audit
  links during backfill and duplicate consolidation.
- Preserve every actionable-message send/receive, payload, supersession, application,
  and safety rule. Refactor a producer only after characterization coverage proves
  behavioral parity; handle any deliberate rule change as separately approved work.
- Run `bin/rubocop -A` after every edit batch.
- Load `.env.test` (or `.env` when absent) before RSpec and use the required PostgreSQL
  permissions.
- Run focused model/service/request coverage throughout and `bin/ci` before completion.
- Coordinate URL behavior with KAKASHI-15 without absorbing unrelated navigation work.

## Slice 1: Inventory and Characterization

Capture the current production shapes before changing persistence.

Deliver:

- a read-only inventory for participant counts, duplicate participants, canonical pair
  duplicates by kind/scenario, missing friendships, missing scenarios, invalid message
  payloads, and action-state contradictions
- characterization specs for existing human, assistant, supersession, apply, auto-apply,
  revert, and scenario behavior
- a producer-by-producer actionable-message compatibility matrix covering send/no-send,
  sender, recipient, conversation scenario, payload, references, supersession, and
  auto-apply result
- an operator-readable report with concrete IDs and no automatic destructive repair

Implementation note: the read-only command and compatibility map are documented in
[`04-current-behavior-inventory.md`](04-current-behavior-inventory.md).

Coverage:

- clean pair
- reversed participant order
- duplicate threads
- zero/one/three-participant rows
- main and derived scenarios
- malformed/legacy headers
- applied, reverted, superseded, and unread combinations
- current create/update/destroy/paid-state/transfer/partial-payment and
  loan/reimbursement producer branches, including their no-message cases

Suggested commit:

```text
spec: characterize conversation and message history
```

## Slice 2: Canonical Conversation Persistence

Add the friendship-backed identity without switching callers yet.

Deliver:

- `friendship_id` and immutable UUID `public_id` on conversations
- main-scenario and derived-scenario database uniqueness constraints
- unique conversation-participant membership
- exact-two-participant and friendship-membership validation
- backfill and deterministic duplicate-thread consolidation
- public-ID model lookup while numeric IDs remain internal

Coverage:

- reverse-order canonical identity
- separate human/assistant threads
- separate main/derived threads
- duplicate consolidation preserving every message/reference/audit link
- ambiguous history reported without mutation
- database rejection under a real uniqueness race

Operational note: preview the canonical assignments and duplicate consolidation with
`bin/rails conversations:backfill`. Apply the reviewed plan with
`CONVERSATION_BACKFILL_APPLY=1 bin/rails conversations:backfill`, then rerun the dry
run and `bin/rails conversations:inventory` as postflight checks. Numeric routes and
existing conversation producers remain unchanged until Slice 3.

Suggested commit:

```text
feat: anchor conversations to canonical friendships
```

## Slice 3: Authorized Resolver and Routes

Replace raw participant creation and scattered `find_or_create` calls.

Deliver:

- one `Logic::Conversations::Resolve` service
- accepted-friendship and exact-scenario guards
- race-safe create-or-load behavior
- friend-aware new-conversation endpoint that accepts a friendship public ID, not a user
  ID
- public conversation URLs and scoped route lookup
- migration of every human and actionable-message producer to the resolver
- parity assertions proving that producer inputs and outputs are unchanged apart from
  canonical conversation identity

Coverage:

- accepted, pending, rejected, blocked, and removed friendships
- outsider and forged friendship/user identifiers
- current user as either canonical friendship side
- missing scenario on either side
- two concurrent create requests returning the same row
- notification producers unable to bypass authorization
- every migrated producer retains its previous send/no-send decision, recipient,
  payload, reference, supersession, and auto-apply behavior

Suggested commit:

```text
feat: resolve conversations through friendships
```

## Slice 4: Participant State and Unread Projection

Move archive, mute, and read progress to the participant boundary.

Deliver:

- `archived_at`, `muted_at`, and `last_read_message_id` on
  `ConversationParticipant`
- participant-scoped archive/unarchive and mute/unmute actions
- unread queries based on the participant cursor and latest nonsuperseded messages
- compatibility/backfill from `messages.read_at`
- recipient unarchive on a new incoming message
- notification delivery honoring mute without suppressing unread or realtime state

Coverage:

- one participant archives/mutes without affecting the other
- new incoming message reactivates only the recipient archive
- mute suppresses email/push but not storage/unread/broadcast
- superseded predecessors do not inflate unread counts
- read progress is isolated across scenarios and conversation kinds
- concurrent show/new-message activity advances monotonically

Suggested commit:

```text
feat: add participant conversation state
```

## Slice 5: Explicit Message Kind and State Machine

Stop inferring presentation/workflow state throughout models, controllers, and views
without changing actionable-message business semantics.

Deliver:

- string-backed message `kind` and nullable `action_state`
- safe legacy backfill using the existing classifier
- centralized transition service for acknowledge, apply, reject, expire, fail,
  unavailable, and revert
- immutable payload/precondition validation boundary
- replacement of timestamp/header conditionals in rendering and filtering
- compatibility assertions between persisted classification/state and the legacy
  predicates before callers switch to the new fields

Coverage:

- every legacy classifier branch
- invalid kind/state combinations
- supersession transitions pending predecessors to expired
- human messages cannot acquire actionable state
- accepted/reverted timestamp compatibility
- malformed payload becomes unavailable rather than raising in a view

Suggested commit:

```text
feat: centralize actionable message states
```

## Slice 6: Unified Idempotent Apply and Action Ledger

Make manual and automatic acceptance two callers of the same guarded operation while
preserving every existing eligibility and financial replay branch.

Deliver:

- shared application service with message row locking
- friendship, recipient, scenario, payload, local-reference, stale-state, paid-history,
  and destructive-action guards
- recipient-policy check at the automatic caller boundary
- append-only message action events linked to resulting `AuditOperation` records
- explicit reject and acknowledge events
- idempotent duplicate-delivery/retry results
- bounded failure codes and localized feedback
- before/after parity fixtures for all currently supported create, update, destroy,
  loan, reimbursement, return, transfer, partial-payment, and paid-history cases

Coverage:

- manual and automatic paths produce the same financial result
- each path produces the same result it produced before this refactor
- duplicate job/request mutates once
- stale payload/local reference denial
- wrong context and wrong actor denial
- policy disabled/enabled
- validation failure is retryable only while preconditions remain valid
- reject and acknowledge idempotency
- action event captures actor, friend, context, conversation, message, outcome, and
  resulting operation

Suggested commit:

```text
feat: unify actionable message application
```

## Slice 7: Revocation and Guarded Revert

Enforce friendship changes across every read, write, stream, and action surface.

Deliver:

- one conversation policy used by controllers, streams, jobs, and services
- immediate access revocation for non-accepted friendships
- retained but hidden history and counts
- pending-message unavailability after revocation
- same-thread restoration if the canonical friendship is accepted again
- guarded revert integration with the explicit action state/event ledger

Coverage:

- block/unfriend between authorization and mutation
- block/unfriend while a page is open
- no list/show/create/message/action/stream access after revocation
- previously applied financial state remains intact
- re-acceptance reuses public conversation identities
- revert available only for an accepted, unsuperseded, still-revertible operation

Suggested commit:

```text
feat: revoke conversation access with friendship state
```

## Slice 8: Friend-Aware Conversation UI

Build the profile-backed conversation experience.

Deliver:

- accepted-friend new-conversation entry and canonical redirect
- profile display name/avatar in index and show
- active, unread, human, assistant, archived, and muted filters
- deterministic last-message summaries, unread counts, and empty states
- selected scenario shown on every conversation surface
- participant archive/mute controls
- local transaction links and return-to-conversation navigation
- no human composer in assistant threads

Coverage:

- attached and fallback avatars
- empty friend list and empty human conversation
- archived/muted filter isolation
- safe actionable previews and missing local references
- desktop/mobile and light/dark rendering
- exact public URLs and Turbo history behavior coordinated with KAKASHI-15

Suggested commit:

```text
feat: add friendship-aware conversation workspace
```

## Slice 9: Cursor Pagination and Authorized Realtime

Bound list size while preserving chronological rendering and live updates.

Deliver:

- keyset pagination for conversation and message lists
- denormalized/indexed conversation activity timestamp maintained transactionally
- older-message prepend flow and stable cursors
- authorized participant stream names/subscriptions
- DOM-ID deduplication for broadcast/page overlap
- participant read-cursor advancement for the visible newest page

Coverage:

- equal timestamps ordered by ID
- inserts between page requests without duplicates or omissions
- older page prepends chronologically
- new broadcast appends once
- archived conversation reactivation and ordering
- revoked/outsider stream subscription denial
- scenario and kind isolation under pagination

Suggested commit:

```text
perf: paginate conversation history safely
```

## Slice 10: Enforcement and Cleanup

Remove bypasses and prove the finished contract.

Deliver:

- removal of controller nested-participant parameters and direct creation paths
- removal/deprecation of `fast_create` and scattered pair queries
- profile-first identity with no entity-name/avatar lookup in conversation views
- database constraints enabled and inventory clean
- repository guard/coverage preventing actionable producers from bypassing the
  canonical resolver without altering their business decisions
- complete English and Portuguese copy
- deployment/backfill runbook and rollback boundaries

Verification:

```sh
bin/rspec spec/models/conversation_spec.rb
bin/rspec spec/models/message_spec.rb
bin/rspec spec/services/logic/conversations
bin/rspec spec/services/logic/friendships
bin/rspec spec/requests/conversations_spec.rb
bin/rspec spec/requests/messages_spec.rb
bin/rspec spec/features/turbo_navigation/conversation_internal_navigation_spec.rb
yarn build
bin/ci
```

Suggested commit:

```text
spec: enforce friendship conversation contract
```
