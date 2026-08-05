# KAKASHI-12 Auto-Accept Implementation Slices

## Overview

When a user enables `auto_accept_actionable_messages` for a specific friend, any financial exchanges or mutations initiated by that friend should be automatically applied to the user's ledger without requiring manual intervention. The actionable messages must still be generated and delivered to the conversation to maintain a clear audit trail, but their UI and state must reflect that the action has already been executed.

## Slice 7 — Core Auto-Apply Execution

**Goal:** Intercept actionable messages upon creation and automatically execute their payloads if the friendship policy permits.

### Deliverables

- **Message Processing Hook:** Add an `after_create_commit` or similar hook in the `Message` lifecycle (or within the service that generates actionable messages) to evaluate the recipient's `FriendshipPolicy`.
- **Policy Evaluation:** Check if the friendship between the sender and recipient has `auto_accept_actionable_messages` enabled.
- **Immediate Execution:** If enabled, immediately invoke the appropriate application service (e.g., `MessageAction::ApplyService` or the equivalent mutation service) to apply the transaction changes to the recipient's ledger.
- **State Transition:** Ensure the message state transitions directly from `pending` to `applied` (or the equivalent terminal state) upon successful automatic execution.

## Slice 8 — Auto-Applied Message UI 

**Goal:** Update the conversation UI to correctly render actionable messages that were automatically applied.

### Deliverables

- **State Detection:** Update the message rendering logic (likely in a Phlex view or partial) to detect when a message was `auto_applied`.
- **Button Swap:** For automatically applied messages, replace the standard "Accept" and "Reject" buttons.
- **Acknowledge (OK) Button:** Add an "OK" button that allows the user to dismiss or acknowledge the notification (if applicable to the UI flow).
- **Revert Button:** Add a "Revert" button that allows the recipient to undo the automatic changes if they disagree with them.

## Slice 9 — Reversion via Audit Trail

**Goal:** Implement the backend capability to safely undo an automatically applied actionable message using the existing audit framework.

### Deliverables

- **Audit Linkage:** Ensure that the automatic application of the message properly creates an `Audit::Operation` linked to the message and the resulting transaction changes.
- **Revert Service:** Create or extend a service to handle the reversion of the specific transaction changes associated with the message, utilizing the `Audit::Operation` to restore the previous state.
- **Revert Action Route:** Expose a controller route (e.g., `POST /messages/:id/revert`) to trigger the reversion from the UI.
- **Post-Revert State:** Upon successful reversion, update the message state (e.g., to `reverted` or `rejected`) and broadcast the UI update to the conversation via Turbo Streams.
