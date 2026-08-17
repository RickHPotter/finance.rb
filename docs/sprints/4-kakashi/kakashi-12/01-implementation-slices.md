# KAKASHI-12 Implementation Slices

## Overview

KAKASHI-12 elevates the user to a first-class product record by adding public profiles, explicit server-backed user preferences, and a formal friendship lifecycle. This establishes a robust foundation for secure transaction exchanges, direct conversations (KAKASHI-13), and per-friend automation policies.

## Slice 1 — User Profiles and Preferences Foundation

**Goal:** Separate public identity from private credentials and introduce a strict, server-backed preferences model.

### Deliverables

- **Profile Surface:** Add a `Profile` model (or expand `User` safely) for `display_name`, `avatar`, `locale`, `timezone`, etc.
- **Dedicated Routing:** Expose profile edits through dedicated controllers/views (e.g., `ProfilesController`) rather than modifying Devise registrations.
- **Preference Record:** Create a `UserPreference` model (1:1 with User) to replace browser-local state and untyped JSON blobs.
- **Persisted Settings:** Support defaults for `theme`, `landing_page`, `active_context`, `exchange_default_bound_type` (e.g., `standalone` vs `card_bound`), `row_color_mode` (e.g., `BADGES_ONLY` vs `ROW_COLOURED`), and `default_cash_transaction_user_bank_account`.
- **Theme Sync:** Synchronize the user's `theme` preference with the early layout boot script to prevent theme flashing on first render.
- **Overrides:** Allow explicit URL or form states to temporarily override the saved preference during a request.
- **Validation:** Validate all preference enums and values server-side.

## Slice 2 — Explicit Friendship Lifecycle

**Goal:** Replace implicit entity-based connections with a canonical, state-managed user-to-user `Friendship` record.

### Deliverables

- **Friendship Model:** Create a `Friendship` record linking two users with a string-backed state enum (`pending`, `accepted`, `rejected`, `blocked`, `removed`).
- **Canonical Lookup:** Enforce a single canonical relationship per user pair (regardless of who initiated the request) via a composite unique index on `[LEAST(user_id, friend_id), GREATEST(user_id, friend_id)]`.
- **Relationship Actions:** Implement services and routes to handle request, accept, reject, cancel, unfriend, and block actions.
- **Identity Protection:** Use non-enumerable IDs (e.g., UUIDs or Hashids) for users/friendships to prevent predictable public routes.
- **Backfill:** Create a migration/rake task to silently backfill `Friendship` records for any existing implicit connections (where `entity_user_id` is present).

## Slice 3 — Entity Reconciliation and Exchange Authorization

**Goal:** Tie financial exchanges and entity creation directly to explicit friendship consent.

### Deliverables

- **Entity Creation:** Modify the entity creation flow so that user-backed entities are only created or reconciled *after* a friendship request is formally accepted.
- **Stable Mapping:** Ensure the `User`-to-`Entity` mapping is stable so that incoming exchanged transactions automatically resolve to the correct local entity without relying on fragile name matching.
- **Exchange Authorization:** Update the `Exchange` logic to authorize notifications and transaction exchanges exclusively through `accepted` friendships.
- **Block Protection:** Prevent any blocked, rejected, or removed friendships from creating new shared transactions or notifications.

## Slice 4 — Auto-Accept Policies and Auditing

**Goal:** Implement granular, safe automation for incoming transactions and track all friendship state changes.

### Deliverables

- **Granular Policies:** Introduce `FriendshipPolicy` (or a JSONB policy structure on the `Friendship` record) to configure automatic actionable-message acceptance on a per-friend basis.
- **Safety Guards:** Enforce strict application-level guards: *never* auto-accept destructive actions, modifications to paid history, ambiguous matches, or actions that fail standard validation.
- **Auditing:** Hook the `Friendship` lifecycle and the `auto-apply` events into the existing KAKASHI-08 `Audit::Operation` framework to ensure a full historical trail of requests, blocks, and automated actions.

## Slice 5 — User Profile and Preferences UI

**Goal:** Create the frontend views and Hotwire interactions for users to view and update their profile and preferences.

### Deliverables

- **Profile Form:** Build a Phlex/Ruby UI form in `app/views/profiles/edit.rb` or `.html.erb` for editing profile details (display name, avatar, locale, timezone).
- **Preferences UI:** Build the preference toggles and select inputs for all server-backed settings (Theme, Landing Page, Active Context, Exchange Default Bound Type, Row Color Mode, Default Cash Transaction Account).
- **Live Updates:** Ensure preferences (like Theme) trigger immediate layout/CSS updates via Turbo streams when changed.
- **Validations Feedback:** Display inline validation errors and success toasts (flash notifications) using existing shared components.

## Slice 6 — Friendships Management UI

**Goal:** Provide the frontend interface for users to search, request, and manage their friendships and auto-accept policies.

### Deliverables

- **Friendships Hub:** Create an index view (`FriendshipsController#index`) listing current friends, pending requests, and blocked users.
- **Request Flow:** Build a form for users to send a friendship request by searching for another user's public identifier.
- **Action Buttons:** Implement Turbo-powered buttons to Accept, Reject, Block, or Cancel pending requests without full page reloads.
- **Policy Configuration:** Add a settings modal/dropdown for each active friend to configure their `FriendshipPolicy` (e.g., toggling `auto_accept_actionable_messages`).
