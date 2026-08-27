# KAKASHI-17 Decisions and Test Matrix

## Locked Product Decisions

### D1 — Show explains; edit mutates

Investment and Subscription show pages are first-class read surfaces. Complex nested
changes stay in the existing edit forms. Show actions may invoke narrow, explicit
mutation endpoints.

### D2 — All record loads are context-scoped

Controllers load through `current_context.investments` and
`current_context.subscriptions`. Related queries also require the active context even
when a foreign key already appears user-owned.

### D3 — Index labels open show; pencil actions open edit

Desktop and mobile lists use the record's primary label as the detail affordance.
Mutation remains available through a distinct edit action.

### D4 — Ordinary Investment and Piggy Bank valuation are different states

An ordinary Investment owns a generated cash projection. A valuation Investment is a
signed adjustment tied to a Piggy Bank return and intentionally skips cash projection
creation. The dashboard terminology and links follow that distinction.

### D5 — Investment value is not redefined

KAKASHI-17 displays the existing `price` semantics. It does not add cost basis, market
value, yield, or a new valuation ledger.

### D6 — Subscription totals are derived from live relationships

The displayed total represents current linked cash plus card transaction prices.
Detached history is informational and is excluded from total and live counters.

### D7 — Open and paid are based on current `paid` state

Unpaid future and overdue transactions are both open. Date presentation distinguishes
future, current, and overdue records without inventing another persisted lifecycle.

### D8 — Detached means proven by audit history

A record enters detached history only when an AuditVersion transition proves it was
formerly linked by `subscription_id`. Similar labels or allocations do not qualify.

### D9 — Current membership wins over old detach events

When a transaction is detached and later reattached, it appears in the appropriate
live section only. Repeated historical transitions are deduplicated by record identity.

### D10 — Lifecycle uses a narrow endpoint

Dashboard lifecycle actions never submit a partial payload to
`SubscriptionsController#update`, because that action synchronizes allocations and
nested records. The lifecycle endpoint changes status only.

### D11 — Finished subscriptions may be reopened

The current edit form already permits any enum status transition. KAKASHI-17 preserves
that capability explicitly: finished offers Reopen, paused offers Resume, and active
offers Pause. Finish remains available from active and paused.

### D12 — Existing model guards remain authoritative

Dashboard visibility mirrors `can_be_destroyed?` and model callbacks, while the server
rechecks the guard. The show page does not create a competing destroy policy.

### D13 — Exact relationship links use IDs, not search strings

Finite sets use explicit IDs; durable associations use their foreign/allocation keys.
Month/year filters are included only when the source claim is month-scoped.

### D14 — Return paths are allowlisted navigation state

Raw arbitrary `return_to` values are never echoed. The destination passes through the
resource's `Navigation::*` policy and retains only bounded, permitted filters.

### D15 — KAKASHI-18 merge logic is reused

Category/entity show pages may expose the merge entry point, but KAKASHI-17 does not
fork or modify merge planning/apply semantics.

### D16 — Actionable-message behavior is frozen

This feature changes neither actionable-message eligibility nor send, receive,
auto-apply, correction, supersession, or revert rules. Any incidental change requires
separate explicit coverage and approval.

## Test Matrix

### Investment Requests and Rendering

| Scenario | Expected |
|----------|----------|
| Guest requests show | redirected by existing authentication contract |
| Same-context investment | 200 and dashboard renders |
| Other-context investment ID | 404 |
| Ordinary investment | ordinary badge, account/type/date/value, generated cash link |
| Ordinary investment without projection | explicit unavailable state, no broken link |
| Valuation investment | adjustment badge and target Piggy Bank return link |
| Valuation sibling link | exact filtered Investment index membership |
| Destroyable record | destroy action visible and server accepts valid request |
| Protected valuation record | destroy hidden/disabled and server preserves record |
| Index primary label | links to `investment_path`, not edit |
| Pencil action | links to edit with approved `return_to` |

### Subscription Requests and Rendering

| Scenario | Expected |
|----------|----------|
| Same-context subscription | 200 and dashboard renders |
| Other-context subscription ID | 404 |
| Empty subscription | zero totals, three useful empty states, guarded destroy visible |
| Cash-only subscription | cash count/value and typed links correct |
| Card-only subscription | card count/value and typed links correct |
| Mixed subscription | derived total includes both types |
| Unpaid past transaction | Open section with overdue date state |
| Unpaid future transaction | Open section with future date state |
| Paid transaction | Paid history only |
| Currently linked after historical detach | live section only |
| Audited detached existing row | Detached history with live show link |
| Audited detached destroyed row | audit tombstone without live link |
| Matching description without audit | absent from detached history |
| Live dependent exists | destroy action unavailable |
| Detached-only history | destroy eligibility follows zero live dependents |

### Lifecycle Transitions

| Current | Event | Expected |
|---------|-------|----------|
| active | pause | paused |
| active | finish | finished |
| paused | resume | active |
| paused | finish | finished |
| finished | reopen | active |
| finished | pause | rejected, unchanged |
| active | reopen | rejected, unchanged |
| any | unknown event | rejected, unchanged |
| any valid transition | allocations and linked transaction IDs unchanged |
| concurrent valid requests | transition evaluated against locked current state |

### Exact Dashboard Drill-downs

For every source action, assert both the exact URL and destination membership.

| Relationship claim | Required positive assertion | Required negative assertion |
|--------------------|-----------------------------|-----------------------------|
| account cash count/list | all context cash rows for account | other accounts and contexts excluded |
| card transaction count/list | all context card rows for user card | other cards and contexts excluded |
| category allocation | all allocated cash/card rows represented by source | same-name and unallocated rows excluded |
| entity allocation | all allocated cash/card rows represented by source | same-name and unallocated rows excluded |
| budget consumption | exact matched installment owners | non-matching period/allocation rows excluded |
| reference descendants | exact type/id descendants | same-description references excluded |
| subscription live transactions | exact `subscription_id` | detached and other subscriptions excluded |
| valuation siblings | exact Piggy Bank return ID | ordinary and other-return investments excluded |
| finite calculated set | exact permitted ID list | any ID outside list excluded |

### Navigation and Return Paths

| Flow | Expected |
|------|----------|
| dashboard -> filtered index | canonical filtered URL with source show `return_to` |
| filtered index -> show | destination retains collection return path |
| show -> edit -> save | returns to the originating approved screen |
| show -> duplicate -> save | duplicate workflow returns through approved chain |
| invalid external `return_to` | resource fallback index |
| oversized ID/filter array | rejected or canonical safe fallback |
| cross-context filter ID | no foreign membership |
| Turbo top-level navigation | `_top`/replace semantics and correct address bar |

## Verification Commands

Before each RSpec command, load `.env.test` when present and `.env` otherwise.

Focused verification grows by slice:

```text
bin/rubocop -A
bin/rspec spec/requests/investments_spec.rb
bin/rspec spec/requests/subscriptions_spec.rb
bin/rspec spec/requests/*dashboard* spec/services/navigation
bin/rspec spec/features/turbo_navigation
bin/rspec
```

The final suite must include explicit regression coverage showing that KAKASHI-17 did
not change actionable-message delivery or application behavior.

