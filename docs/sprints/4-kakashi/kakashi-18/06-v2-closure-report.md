# KAKASHI-18 V2 Closure Report

## Status

Complete as of 2026-09-08. All eight V2 slices and every gate in the V2
completion contract are satisfied.

## Delivered Boundary

- Category and Entity plans inventory the complete source graph inside the
  selected context and fail closed on cross-context, unowned, or unsupported
  allocations.
- Signed previews bind actor, context, mode, exact row identities, conflict
  facts, and relevant master-record state.
- Apply locks deterministically, replans under lock, compares the exact digest,
  performs one atomic mutation, validates the final graph, and refreshes derived
  Budget and counter state.
- Category merge is strict and all-or-nothing. Entity merge supports strict and
  independently safe eligible-only application.
- Strict Category and Entity merges and eligible-only Entity transfers are
  captured by KAKASHI-08 and have guarded rollback coverage.
- Eligible desktop and mobile Category/Entity index rows open an in-place Turbo
  chooser and preview. Protected or inactive sources expose no trigger, forged
  requests remain governed by server policy, and show pages expose no merge
  action.
- Combobox labels and aliases use normalized exact, starts-with, word-start, and
  substring tiers with stable ordering and primary-label precedence.
- User Bank Account discovery uses bank, agency, full account, and account
  suffix aliases. User Card discovery uses card brand; `user_card_name` is the
  stable identifying label because the schema contains no card-number suffix.

## Verification

The final focused run covered planners, strict and eligible-only apply,
previews, canonical navigation, desktop/mobile browser behavior, deterministic
concurrency, audit ownership, guarded rollback, helper aliases, and JavaScript
ranking. The focused Ruby matrix passed with 131 examples and the six
JavaScript spec files passed.

The final `bin/ci` acceptance gate passed on the completed tree:

- 1,900 RSpec examples, zero failures;
- 23 JavaScript tests, zero failures;
- 916 Ruby files and 104 ERB files linted without offenses;
- no vulnerable gems reported by Bundler Audit;
- zero Brakeman security warnings.

## Deliberately Rejected Future Scope

The following remain outside KAKASHI-18 rather than unfinished work:

- merging multiple source records in one operation or bulk-selecting sources;
- eligible-only Category merging;
- merging across users or contexts;
- moving Subscription-owned allocations through the generic merge path;
- merging built-in or system-managed records;
- automatic fuzzy/name-based deduplication;
- a Category or Entity show-page merge entry point;
- dedicated merge-history UI beyond the KAKASHI-08 audit trail;
- virtualized selector lists or punctuation-insensitive/fuzzy search;
- fabricated card last-four aliases without a real model field.

Any future expansion must preserve the exact-preview, deterministic-lock,
atomic-apply, and guarded-rollback boundaries established here.
