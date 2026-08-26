# KAKASHI-13 Decisions and Test Matrix

## Resolved Product Decisions

### D0. Does KAKASHI-13 change actionable-message business rules?

Decision: no. Existing send/no-send, sender, recipient, scenario, payload, reference,
supersession, safety, manual-apply, auto-apply, destroy, and revert rules are invariants.
KAKASHI-13 may refactor their conversation plumbing only with before/after coverage.
Any intentional behavior change requires an explicit product decision and separately
identified regression coverage.

### D1. What is the canonical relationship owner?

Decision: the existing canonical `Friendship` row. A conversation belongs to one
friendship instead of reconstructing identity from entity names or participant order.

### D2. How many direct threads exist?

Decision: one per friendship, kind, and scenario. `human` and `assistant` remain
separate; main and derived scenarios remain separate.

### D3. How is main context represented?

Decision: `scenario_key = NULL`, matching the current context contract. Separate
partial unique indexes make null main scope unique without inventing a sentinel key.

### D4. Can a browser submit participant user IDs?

Decision: no. It submits an accepted friendship public ID; the server derives both
participants and the current scenario.

### D5. What identifiers appear in conversation URLs?

Decision: immutable UUID public IDs. Numeric database IDs never become public lookup
credentials.

### D6. What happens during concurrent thread creation?

Decision: database uniqueness chooses one winner and all callers return that same
conversation. Application-only `find_or_create` is insufficient.

### D7. What happens after block or unfriend?

Decision: both users immediately lose list, show, send, action, and stream access.
History and audit evidence remain stored. Re-acceptance restores the same canonical
threads.

### D8. Does revocation undo applied financial activity?

Decision: no. It prevents new conversation/action access. Reversal remains an explicit,
guarded audit operation.

### D9. Who owns archive and mute state?

Decision: each conversation participant independently. Neither action changes the
other participant's view.

### D10. What does mute mean?

Decision: suppress attention channels such as email/push and the conversation tab
notification dot. Delivery, unread state, unread filtering, realtime rendering, and
financial action availability remain intact.

### D11. What does a new message do to an archive?

Decision: it clears the recipient's archive and the sender's archive for that
conversation. A conversation with new activity cannot remain silently hidden.

### D12. What is the unread source of truth?

Decision: the participant's last-read message cursor. Existing message `read_at`
timestamps are retained for compatibility/history but no longer decide participant
unread state.

### D13. Are superseded messages unread?

Decision: no. Only the latest visible replacement contributes to unread/actionable
counts. Superseded history remains linkable from the replacement chain.

### D14. Are message kinds inferred at render time?

Decision: no after migration. Kind is persisted and string-backed. The existing
classifier is used once for backfill and as a compatibility assertion.

### D15. Which actionable states are persisted?

Decision: `pending`, `accepted`, `rejected`, `expired`, `failed`, `unavailable`, and
`reverted`. `auto_applied` remains provenance for an accepted action.

### D16. Do manual and automatic apply use separate implementations?

Decision: they may share one locking and audit orchestration path only when parity tests
prove all current validation, mutation, failure, and eligibility branches remain
unchanged. The automatic caller retains exactly its existing recipient-policy gate.

### D17. What makes apply idempotent?

Decision: a locked message, explicit state transition, immutable precondition check,
and unique successful action effect. Retried delivery returns the prior result without
repeating the mutation.

### D18. How are action attempts audited?

Decision: an append-only message-action event records every attempt/outcome and links
the resulting financial `AuditOperation`. The originating operation link is never
overwritten.

### D19. What happens when a derived scenario cannot be resolved?

Decision: fail closed. There is no fallback to either user's main context.

### D20. Which identity appears in conversation UI?

Decision: `UserProfile#display_name` and profile avatar, with the shared avatar
fallback. Entity names and entity avatars are financial allocation data, not public
identity.

### D21. How are lists paginated?

Decision: cursor/keyset pagination. Conversation order is activity then ID; message
order is creation time then ID. This prevents offset drift under realtime inserts.

### D22. Are financial messages deletable?

Decision: no. Archive, mute, friendship changes, and message filters never destroy
message or audit history.

## Canonical Identity Matrix

| Scenario | Expected result |
| --- | --- |
| accepted friendship, human, main | one canonical human conversation |
| same pair in reverse order | same conversation |
| accepted friendship, assistant, main | separate canonical assistant conversation |
| same pair and kind, derived scenario A | separate scenario-A conversation |
| same pair and kind, derived scenario B | separate scenario-B conversation |
| two concurrent creates | one row; both return it |
| duplicate participant insertion | database rejection |
| third participant insertion | validation/database guard rejection |
| forged user ID | ignored/rejected; participants derive from friendship |
| numeric conversation URL | not routable as public conversation identity |

## Friendship Authorization Matrix

| Friendship state | Existing history stored | List/show | Human send | New actionable delivery | Apply/reject/revert | Stream |
| --- | --- | --- | --- | --- | --- | --- |
| accepted | yes | allowed | allowed | allowed | allowed when state permits | allowed |
| pending | yes | denied | denied | denied | denied | denied |
| rejected | yes | denied | denied | denied | denied | denied |
| blocked | yes | denied | denied | denied | denied | denied |
| removed | yes | denied | denied | denied | denied | denied |

Authorization is checked at request/job execution time, not only when a page or job is
created.

## Participant State Matrix

| Scenario | Expected result |
| --- | --- |
| Rikki archives | hidden for Rikki; unchanged for Gigi |
| Gigi sends new message | Rikki's archive clears |
| Rikki mutes | Rikki email/push suppressed; Gigi unchanged |
| muted incoming message | stored, broadcast, and unread |
| Rikki reads human thread | only Rikki cursor advances |
| Rikki reads main assistant thread | derived assistant cursor unchanged |
| superseded unread predecessor | does not add unread count |
| unarchive without new message | visible with original activity ordering |

## Message Classification and State Matrix

| Message shape/event | Kind | Initial/result state |
| --- | --- | --- |
| body only, no financial reference | `human` | no action state |
| notification V2 create/update | `transaction_notification` | `pending` |
| notification V2 destroy | `transaction_destroy_notification` | `pending` |
| paid-state V1 | `paid_state_sync` | `pending` |
| successful manual apply | unchanged | `accepted`, automatic false |
| successful policy apply | unchanged | `accepted`, automatic true |
| explicit decline | unchanged | `rejected` |
| superseded before acceptance | unchanged | `expired` |
| validation/persistence failure | unchanged | `failed` |
| stale/missing/ambiguous reference | unchanged | `unavailable` |
| successful guarded rollback | unchanged | `reverted` |
| malformed legacy headers | classified/reported safely | `unavailable` when actionable intent exists |

## Apply and Audit Matrix

| Scenario | Expected result |
| --- | --- |
| manual valid create/update/destroy | one mutation, accepted state, action event and audit operation |
| automatic valid action, policy on | same result path, automatic provenance |
| automatic action, policy off | remains pending; no mutation |
| simultaneous manual/job apply | one mutation; loser gets idempotent result |
| duplicate job delivery | no second mutation or success operation |
| wrong recipient | denied event; no mutation |
| wrong scenario | denied/unavailable; no main-context fallback |
| friendship revoked after enqueue | denied at execution |
| local reference changed since payload | unavailable; no overwrite |
| validation failure | failed with bounded code and localized UI |
| explicit reject repeated | one state transition; repeat idempotent |
| paid-state acknowledgement | accepted without financial mutation operation |
| revertible accepted action | reverted event linked to rollback operation |
| superseded or later-mutated action | revert absent/denied |

## Actionable-Message Compatibility Matrix

For every current producer fixture, the pre-KAKASHI-13 and post-refactor observations
must match in every column except the internal conversation record ID:

| Observation | Required parity |
| --- | --- |
| message emitted | same yes/no decision |
| sender | same user |
| recipient | same user |
| conversation kind | same assistant kind |
| scenario | same exact scenario key; no fallback |
| notification version/action | same semantic value |
| replay payload | equivalent transaction/category/installment/entity/exchange data |
| reference transactable | same intended source/local chain semantics |
| superseded message | same predecessor selection |
| auto-apply candidacy | same decision |
| application result | same financial mutation or same refusal/failure |
| audit parentage | same originating financial operation semantics |

The fixture set includes create, update, destroy, paid/unpaid state, date transfer,
partial payment from either participant, full final payment, category replacement,
loan-to-reimbursement and reimbursement-to-loan changes, shared exchange returns,
borrow returns, cash/card sources, main/derived scenarios, and all established
no-message safety branches.

## Pagination and Realtime Matrix

| Scenario | Expected result |
| --- | --- |
| conversations share activity timestamp | ID tie-break gives stable order |
| messages share creation timestamp | ID tie-break gives stable order |
| new conversation activity between pages | no duplicate/omitted older rows |
| load older messages | prepend in chronological display order |
| broadcast overlaps loaded page | one DOM message |
| new message in archived thread | thread reactivates and moves by activity order |
| outsider guesses stream | subscription denied/no data |
| friendship revoked with page open | no future authorized delivery; endpoints deny |
| main/derived conversations paginate | cursors never cross scenario scope |

## Migration Matrix

| Historical shape | Migration behavior |
| --- | --- |
| valid two-user accepted friendship | attach friendship |
| reversed participant order | same canonical friendship |
| duplicate same kind/scenario threads | oldest canonical row survives; all messages move deterministically |
| duplicate participant rows | collapse after proving identical user |
| zero/one/three participants | report; do not guess |
| missing friendship with proven legacy entity link | use KAKASHI-12 reconciliation path |
| ambiguous missing friendship | report; do not mutate |
| valid legacy actionable message | persist classified kind/state |
| malformed payload | preserve raw data and report |
| supersession chain | preserve IDs and links |
| existing audit link | preserve as originating link |
| main scenario | keep nil and enforce partial unique index |
| missing derived scenario mapping | report/unavailable; never remap to main |

## Manual Acceptance Matrix

| Surface | Checks |
| --- | --- |
| conversation index | friend identity, scenario, kind, preview, unread, deterministic order |
| new conversation | accepted friends only; selecting twice opens same thread |
| human show | empty state, composer, pagination, archive/mute, realtime message |
| assistant show | no composer, state filters, transaction links, apply/reject/revert controls |
| archived/muted filters | participant isolation and clear state controls |
| blocked/removed friendship | all routes denied; no counts or streamed updates |
| derived context | visible badge and no fallback after missing mapping |
| mobile/light/dark | usable headers, filters, controls, composer, and older-message loading |
| browser history | index/show/new/filter navigation has the URL promised by KAKASHI-15 |

## Remaining Product Decisions

There are no blocking V1 decisions. Later work may consider:

- allowing a read-only user-visible history after unfriend (blocked history should
  remain inaccessible)
- separate mute controls for human and financial notification channels
- message search, attachments, reactions, or group conversations
- retention/deletion policy after account deletion
