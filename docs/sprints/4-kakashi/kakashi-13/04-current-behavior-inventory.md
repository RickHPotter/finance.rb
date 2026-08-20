# KAKASHI-13 Current Behavior Inventory

## Read-Only Operator Report

Run:

```sh
bin/rails conversations:inventory
```

The command performs no writes. It prints concrete conversation, participant, and
message IDs for every detected issue, together with a summary suitable for retaining
in deployment notes.

| Issue | Meaning |
| --- | --- |
| `invalid_participant_count` | conversation does not contain exactly two participant rows |
| `duplicate_participant` | the same user occurs more than once in one conversation |
| `duplicate_canonical_thread` | the same user pair, kind, and scenario has multiple conversations |
| `missing_friendship` | a two-user conversation has no canonical friendship |
| `friendship_not_accepted` | history exists but its friendship is not currently accepted |
| `missing_scenario` | one or both participants lack the conversation's exact main/derived context |
| `invalid_message_payload` | JSON, version, event action, or replay shape is invalid |
| `action_state_contradiction` | legacy timestamps/provenance cannot map safely to one action state |

The report is intentionally diagnostic. Slice 1 does not attach friendships, merge
threads, rewrite payloads, or infer corrections for ambiguous history.

## Canonical Persistence Backfill

Slice 2 adds friendship-backed identity without switching routes or message producers.
Preview the exact mutations first:

```sh
bin/rails conversations:backfill
```

After reviewing the listed canonical conversation, friendship, duplicate conversation,
and message IDs, apply that same plan with:

```sh
CONVERSATION_BACKFILL_APPLY=1 bin/rails conversations:backfill
```

The oldest conversation ID in an otherwise identical friendship/kind/scenario group is
retained. Messages are moved without recreating them, preserving their IDs, timestamps,
references, supersession chains, and audit links. Ambiguous participant, friendship, or
scenario history is reported and left untouched. The apply operation locks the affected
friendships and conversations, rejects a stale plan, and is idempotent.

Postflight both read-only commands; a completed clean backfill reports zero actions and
zero inventory issues:

```sh
bin/rails conversations:backfill
bin/rails conversations:inventory
```

## Existing Lifecycle Characterization

These suites are the behavior-parity boundary before later slices change persistence
or routing:

| Behavior | Characterization coverage |
| --- | --- |
| human/assistant identity and reverse participant order | `spec/models/conversation_spec.rb` |
| main/derived scenario isolation | `spec/models/conversation_spec.rb`, `spec/requests/conversations_spec.rb`, `spec/requests/messages_spec.rb` |
| legacy and V2 message classification/rendering | `spec/models/message_spec.rb` |
| supersession, pending visibility, and read propagation | `spec/requests/conversations_spec.rb`, `spec/models/cash_transaction_spec.rb` |
| manual apply/acknowledge | `spec/requests/conversations_spec.rb`, `spec/requests/messages_spec.rb` |
| automatic apply and policy/safety denial | `spec/services/logic/friendships/auto_accept_actionable_message_service_spec.rb` |
| guarded revert and supersession denial | `spec/services/logic/friendships/revert_auto_apply_service_spec.rb`, `spec/requests/messages_spec.rb` |
| context-bound financial replay | `spec/requests/cash_transactions_spec.rb`, `spec/requests/cash_installments_spec.rb` |

## Actionable Producer Compatibility Matrix

Every observation below is locked before a producer is migrated to the canonical
conversation resolver. “Parity” means message emission, sender, recipient, assistant
kind, exact scenario, payload, reference, supersession, auto-apply candidacy, and final
application outcome remain unchanged.

| Producer / trigger | Send and no-send boundary | Payload/reference/supersession boundary | Auto-apply/result boundary |
| --- | --- | --- | --- |
| `FriendNotifiable` create/update/destroy callbacks | accepted friendship, user-backed exchange allocation, no self/reference echo; covered by `exchange_notification_authorization_spec.rb` and `cash_transaction_spec.rb` | V2 create/update/destroy, loan/reimbursement intent, canonical reference family, derived scenario, and destroy survivor coverage in `cash_transaction_spec.rb` | create/update conversion and destroy safety in `auto_accept_actionable_message_service_spec.rb` |
| `SharedReturnStructureUpdateMessageService` after partial payment or structural transfer | counterpart and reference required plus accepted friendship; covered by `exchange_notification_authorization_spec.rb` and the partial-payment request examples | merged update payload, exact counterpart chain, and predecessor supersession in `cash_installments_spec.rb` | mirrored loan/reimbursement partial-pay outcomes from either side in `cash_installments_spec.rb` |
| `SharedReturnDestroyMessageService` after linked return removal | counterpart plus accepted friendship required; duplicate delivery is suppressed | destroy payload, surviving counterpart reference, and family supersession in `cash_transaction_spec.rb` and `exchange_notification_authorization_spec.rb` | unpaid destroy accepted and paid destroy denied in `auto_accept_actionable_message_service_spec.rb` |
| `SharedPaidStateSyncService` after pay/unpay/full/partial operations | only canonical linked shared returns emit; unresolved or structurally similar unlinked rows do not | paid-state V1 for pure state changes; structural changes emit V2 update and supersede the same family, covered by `cash_installments_spec.rb` | paid-state remains acknowledgement-only; structural updates retain the existing automatic replay result |
| `CashTransactionsController` explicit shared paid-state notification | current counterpart and scenario determine receiver/conversation; no raw browser participant selection | paid-state V1 contains the current installment and transaction facts | never enters financial auto-apply; acknowledgement marks it read/applied |
| Human `MessagesController#create` | current participant and exact scenario scope are required by the current controller | body only; browser actionable fields are not permitted | no automatic application |

### Locked Scenario Fixtures

The compatibility suite includes main and derived contexts, create/update/destroy,
paid/unpaid synchronization, date transfer, partial payment from either participant,
final full payment, category replacement, loan-to-reimbursement and reimbursement-to-
loan changes, cash/card sources, shared exchange returns, borrow returns, and established
no-message branches. Later slices must add before/after assertions before replacing any
producer call site; this matrix does not authorize changing its financial rules.
