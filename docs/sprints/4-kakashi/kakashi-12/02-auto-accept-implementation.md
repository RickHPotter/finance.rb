# KAKASHI-12 — Remaining Implementation Slices

## Overview

This document covers all outstanding work for the `feature/kakashi-12` branch that was not addressed in the first round of implementation. It supersedes the previous version of this file. Slices are numbered starting at 7 to continue from `01-implementation-slices.md`.

---

## Slice 7 — Exchange Notification Authorization Guards

**Goal:** Ensure that the `FriendNotifiable` concern never generates actionable messages across a friendship that is no longer active. Currently a blocked, removed, or rejected friendship silently continues to produce shared-transaction notifications.

### Context

`FriendNotifiable#notify_friend` (in `app/models/concerns/friend_notifiable.rb`) fetches `friend_user` from an `Entity` that carries a `friendship_id`, but it never checks the friendship's `state` before opening a conversation or writing a message. Likewise, `SharedReturnStructureUpdateMessageService` and `SharedReturnDestroyMessageService` find the counterpart transaction and create messages without verifying the friendship is still `accepted`.

### Deliverables

- **FriendNotifiable guard:** In `notify_friend`, after resolving `friend_user`, retrieve the canonical `Friendship` via `user.friendship_with(friend_user)` and return early unless `friendship&.accepted_state?`.
- **SharedReturn services guard:** In both `SharedReturnStructureUpdateMessageService#call` and `SharedReturnDestroyMessageService#call`, resolve the friendship between the two transaction owners and return `false` early unless it is `accepted`.
- **SharedPaidStateSyncService guard:** Apply the same guard to the sections that call `Conversation.find_or_create_assistant_between!` for friend notifications.
- **Specs:** Add model or request specs asserting that no `Message` is created when the friendship is `blocked`, `removed`, or `rejected`.

---

## Slice 8 — Auto-Apply Service: Correctness and Coverage

**Goal:** Harden `AutoAcceptActionableMessageService` with explicit boolean casting and a proper spec suite.

### Context

The service was previously applying transactions to the _sender's_ context instead of the _recipient's_. This has been patched. However, two correctness issues remain:

1. `auto_accept_actionable_messages` is stored as a JSONB string (`"true"` / `"false"`), and the service currently guards with `["true", true].include?(...)`, which works but is fragile.
2. There is no spec file for this service, making future regressions invisible.

### Deliverables

- **Boolean cast on `Friendship`:** Change the `store_accessor` declaration to use a typed cast:
  ```ruby
  store_accessor :policies, :auto_accept_actionable_messages, :boolean
  ```
  This makes `friendship.auto_accept_actionable_messages` return `true`/`false` directly. Update `policy_allows?` to simply compare the boolean attribute.
- **Recipient-first lookup comment:** Add an inline comment in `policy_allows?` clarifying that `message.user` is the _sender_ and `friend_user` (the other conversation participant) is the _recipient_ whose policy is being checked. The `friendship_with` lookup is symmetric — this must be documented to avoid future confusion.
- **Spec file:** Create `spec/services/logic/friendships/auto_accept_actionable_message_service_spec.rb` covering:
  - Does not apply when `auto_accept_actionable_messages` is `false`.
  - Does not apply for destroy-type messages.
  - Does not apply when the payload contains paid installments.
  - Applies correctly for a `create`-type message: creates a cash transaction on the _recipient's_ context.
  - Applies correctly for an `update`-type message: updates the matching cash transaction on the _recipient's_ context.
  - Creates an `AuditOperation` linked to the originating message's `audit_operation_id` as `parent_operation_id`.
  - Sets `applied_at` on the message after successful application.

---

## Slice 9 — Auto-Applied Message UI: State Differentiation and Acknowledge

**Goal:** Make the conversation view correctly communicate to the recipient that a message was applied automatically, and offer an "OK" dismiss action.

### Context

`render_completed_state` in `Views::Messages::Message` currently renders the same badge and edit link whether the message was manually accepted or auto-applied in the background. There is no way to distinguish the two in the UI, and there is no acknowledge path for auto-applied messages.

### Deliverables

- **`auto_applied` column on `messages`:** Add `t.boolean :auto_applied, default: false, null: false` via migration. Set it to `true` inside `AutoAcceptActionableMessageService#apply!` alongside `applied_at`. Add `Message#auto_applied?` predicate.
- **Updated `render_completed_state`:** In `Views::Messages::Message`, when `message.auto_applied?` is true, render a distinct badge (e.g., `"auto_applied"` locale key) in addition to the standard completed badge.
- **"OK" acknowledge button:** Render a small "OK" button below the auto-applied badge when `message.auto_applied?` and the current user is the recipient (`message.user != current_user`). The button points to `apply_conversation_message_path` (existing route). Pressing it sets `read_at` on the message to indicate the recipient has seen the notification. No other state changes occur.
- **"Revert" button placeholder:** Render a danger-tinted "Revert" button alongside the "OK" button (implementation in Slice 10).
- **Conditional guard:** Only show the Revert and OK buttons when `message.user != current_user` (i.e., only the recipient sees them, not the sender).
- **Turbo Stream broadcast on auto-apply:** Inside `AutoAcceptActionableMessageService#apply!`, after setting `applied_at` and `auto_applied`, broadcast `turbo_stream.replace(dom_id(message), ...)` so the recipient's open session updates in real-time without a page reload.

---

## Slice 10 — Revert Auto-Applied Message via Audit Trail

**Goal:** Allow the recipient of an auto-applied message to undo the change using the existing `Audit::Rollback` infrastructure.

### Context

The route `PATCH /conversations/:conversation_id/messages/:id/revert` already exists but `MessagesController#revert` is not implemented. The `Audit::Rollback::Apply` service exists but is admin-only and requires a signed preview token — a lighter-weight, friendship-scoped revert path is needed.

### Deliverables

#### Database

- **`reverted_at` column on `messages`:** `t.datetime :reverted_at, index: true`. Add `Message#reverted?` predicate.
- `applied?` and `reverted?` are mutually exclusive terminal states. Guard `render_message_actions` to hide action buttons when either is true.

#### Service — `Logic::Friendships::RevertAutoApplyService`

Create `app/services/logic/friendships/revert_auto_apply_service.rb`:

- **Inputs:** `message:`, `actor:` (the requesting user), `context:` (actor's active context).
- **Authorization:** Verify the actor is the message recipient (`message.user != actor`) and participates in the conversation. Return a failure result otherwise.
- **Safety guards:** Return failure if `message.reverted?` or `!message.auto_applied?`.
- **Rollback execution:** Retrieve the `AuditOperation` via `message.audit_operation`. Use a new internal `Audit::Rollback::DirectApply` service (or extend `Audit::Rollback::Apply` with a trusted-caller bypass) that performs the rollback without requiring an admin actor or a signed token. Record a new `AuditOperation(source: :rollback, rollback_of_operation_id: original_operation.id)`.
- **Post-revert:** Write `reverted_at: Time.current` on the message inside the same transaction.
- **Return value:** A result struct with `.reverted?` and `.failure_reason`.

#### Controller — `MessagesController#revert`

Implement the `revert` action following the same shape as `apply`:

```ruby
def revert
  @conversation = current_user.conversations.for_scenario(current_context.scenario_key)
                               .find(params[:conversation_id])
  @message = @conversation.messages.find(params[:id])

  result = Logic::Friendships::RevertAutoApplyService.new(
    message: @message, actor: current_user, context: current_context
  ).call

  respond_to do |format|
    format.turbo_stream
    format.html do
      target = conversation_path(@conversation, message_filter: params[:message_filter])
      if result.reverted?
        redirect_to target, notice: I18n.t("messages.revert.success"), status: :see_other
      else
        redirect_back fallback_location: target, alert: I18n.t("messages.revert.#{result.failure_reason}"), status: :see_other
      end
    end
  end
end
```

Add `audit_operation_source` (`:actionable_message`) and `audit_parent_operation_id` overrides for the `revert` action.

#### View

- **"Revert" button in `render_completed_state`:** When `message.auto_applied? && !message.reverted? && message.user != current_user`, render a danger-tinted button pointing to `revert_conversation_message_path`.
- **Post-revert badge:** Once `message.reverted?`, replace the auto-applied badge with a "Reverted" badge and remove both action buttons.
- **Turbo Stream template:** Create `app/views/messages/revert.turbo_stream.erb` (and `apply.turbo_stream.erb` if not already present) that broadcasts `turbo_stream.replace(dom_id(@message), ...)` to update the message frame for all conversation participants.

#### Specs

- `spec/services/logic/friendships/revert_auto_apply_service_spec.rb`
  - Reverts the cash transaction and sets `reverted_at`.
  - Records a rollback `AuditOperation` linked to the original auto-apply operation.
  - Fails when the actor is not the recipient.
  - Fails when the message was already reverted.
  - Fails when the message was not auto-applied.
- `spec/requests/messages_spec.rb` — add `PATCH revert` request specs covering success, unauthorized actor, and non-auto-applied message.

---

## Slice 11 — Friendship State Auditing

**Goal:** Record an `AuditOperation` for every friendship lifecycle transition so the audit log contains a complete relationship history.

### Context

`Friendship` includes `FinancialAuditable` and calls `audits_financial_changes`, which sets up `has_paper_trail`. However, `FriendshipsController` calls `friendship.update!` directly without an enclosing `Audit::Operation.record` context, meaning no `AuditOperation` is created and the `operation_id` meta field on every `AuditVersion` is blank.

### Deliverables

- **Wrap state changes:** In `FriendshipsController#handle_state_update` and `#handle_policy_update`, wrap `friendship.update!` with `Audit::Operation.record(source: :web, ...)` following the same pattern as other controllers in the app. The `ApplicationController` concern should wire `Audit::Current` automatically per request; confirm this also fires for the friendships controller.
- **Skip policy-only paper trail versions (optional):** Policy updates (`auto_accept_actionable_messages` changes) are not financial mutations. Consider passing `skip: [:policies]` to `audits_financial_changes` on `Friendship` to keep the audit log free of noise, or add a custom `VersionMetadata` filter.
- **Specs:** Add entries in `spec/requests/friendships_spec.rb` asserting that `AuditOperation` and `AuditVersion` records are created when a friendship is accepted, rejected, or blocked.

---

## Slice 12 — Friendship UX Hardening

**Goal:** Fix several UX gaps and controller correctness issues discovered during review.

### Deliverables

#### 12a. Cancel Sent Request

- **View:** In `Views::Friendships::Index`, render a "Cancel" button (distinct from "Remove") next to sent pending requests where `friendship.user == current_user && friendship.pending_state?`.
- **Controller:** In `FriendshipsController#destroy`, permit the initiator to cancel their own pending request. The state should transition to `"removed"` (or a new `"cancelled"` enum value if the semantic distinction matters) only when `friendship.user == current_user && friendship.pending_state?`. Reject requests that don't match this condition with an appropriate flash alert.
- **I18n:** Add `friendships.notices.cancelled` and `friendships.alerts.cannot_cancel` locale keys.

#### 12b. I18n Controller Alerts

- Replace every hardcoded English string in `FriendshipsController` (e.g., `"Friend request sent."`, `"User not found."`, `"You cannot friend yourself."`, `"Could not send friend request."`, `"Friendship removed."`, `"Friend request accepted."`, `"Friend request rejected."`, `"User blocked."`, `"Friendship policy updated."`) with `I18n.t("friendships.notices.*")` / `I18n.t("friendships.alerts.*")` keys.
- Add all keys to `config/locales/en.yml` (and `pt-BR.yml` if applicable).

#### 12c. `landing_page` Validation

- The `landing_page` column on `user_preferences` is a plain string with default `"cash_transactions"` and no model-level validation.
- Define a `LANDING_PAGES` constant listing all valid static values (e.g., `%w[cash_transactions card_transactions balance investments budgets subscriptions]`).
- Add a custom validator (or inclusion validator with a proc) that accepts any value in `LANDING_PAGES` **or** matching the pattern `"card_transactions_\d+"` (for per-card shortcuts).

#### 12d. Auto-Accept Toggle Turbo Response

- `FriendshipsController#update` currently issues a full redirect after a policy update, causing the page to scroll to top and flash to appear only on next load.
- Add `format.turbo_stream` to the `respond_to` block in `#update`.
- Create `app/views/friendships/update.turbo_stream.erb` that morphs only the relevant friendship card via `turbo_stream.replace(dom_id(friendship), partial: "friendships/friendship_card", locals: { friendship: })`.
- Extract the accepted-friend card into a `_friendship_card.html.erb` partial (or a Phlex component method) so it can be rendered in isolation for the stream replacement.

---

## Slice 13 — Profile Schema Completeness: Avatar

**Goal:** Align the `user_profiles` and `user_preferences` database schemas with all deliverables listed in Slice 1 of `01-implementation-slices.md`.

### Deliverables

#### 13a. Avatar / Profile Picture

- **Strategy (recommended):** Use the existing `IconPicker` component rather than Active Storage file uploads. Store the chosen icon key as a `avatar_name :string` column on `user_profiles`.
- **Migration:** `add_column :user_profiles, :avatar_name, :string`.
- **Profile form:** Add the `IconPicker` to the profile edit form scoped to the `PEOPLE_ICONS_PATH` set.
- **Display locations:**
  - Friendships index: avatar next to each friend's `display_name`.
  - Conversation header: sender avatar alongside the assistant robot icon.
  - Profile/preference page header.

---

## Implementation Order (Recommended)

| Priority | Slice | Rationale |
|---|---|---|
| 1 | **7** — Exchange guards | Stops data leakage across blocked/removed friendships immediately |
| 2 | **8** — Auto-apply correctness | Fixes boolean casting and adds regression coverage before further UI work |
| 3 | **10** — Revert (backend) | Completes the auto-accept contract; unblocks UI work |
| 4 | **9** — Auto-applied UI | Makes the auto-accept flow visible and interactive for the recipient |
| 5 | **11** — Friendship auditing | Audit hygiene; low effort, high value |
| 6 | **12** — UX hardening | Polish, i18n, and correctness |
| 7 | **13** — Schema completeness | Low-urgency schema alignment |
