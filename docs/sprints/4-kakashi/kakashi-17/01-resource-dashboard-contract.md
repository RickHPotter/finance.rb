# KAKASHI-17 Resource Dashboard Contract

## Objective

Complete the application's resource `show` surface and make every dashboard
drill-down truthful: a link that claims to list a relationship must open an index
containing exactly that relationship, within the current context, with a useful way
back to the source dashboard.

KAKASHI-17 has three connected parts:

1. add first-class Investment and Subscription dashboards;
2. harden relationship links on the existing financial dashboards;
3. standardize dashboard navigation, empty states, and guarded actions.

The edit form remains the mutation workspace. A show page explains current and
historical state, links to related records, and exposes only actions that are valid.

## Current-State Inventory

The application already has Phlex show dashboards for:

- CashTransaction
- CardTransaction
- Budget
- UserBankAccount
- UserCard
- Category
- Entity

Investment and Subscription are the two missing resource dashboards. Their routes
currently use `except: :show`, their controllers do not load records for `show`, and
their index rows send the record label directly to `edit`.

Existing dashboards already provide the visual language to reuse: a summary header,
metric cards, collapsible sections, mobile detail cards, audit/edit/duplicate/destroy
actions, and `return_to`-aware top-level navigation. KAKASHI-17 consolidates these
patterns; it does not introduce a second dashboard design system.

## Shared Show Contract

Every dashboard in scope must:

- load the record through `current_context`, never through an unscoped user relation;
- render as the top-level `center_container` surface;
- accept only a navigation-service-approved `return_to` destination;
- link the record's primary label to `show` from index rows, while retaining a
  distinct pencil/edit action;
- preserve `return_to` through show -> edit/duplicate/action -> successful return;
- provide localized, explicit empty states instead of blank sections;
- use exact string DOM IDs wherever tests or Stimulus depend on the ID;
- render RubyUI and local components directly from Phlex;
- keep destructive actions hidden or disabled when the model's existing guard says
  the record cannot be destroyed;
- keep all record and relationship lookups inside the active context.

Dashboard links use `_top` and `replace` semantics when they complete a top-level
navigation. Bounded interactive sections may continue to use Turbo frames.

## Investment Dashboard

### Record Kinds

The dashboard must identify the Investment row before interpreting its amount:

| Kind | Identification | Meaning of `price` | Related projection |
|------|----------------|--------------------|--------------------|
| Ordinary investment | `piggy_bank_return_cash_transaction_id` is blank | contributed principal/value for this investment entry | generated `cash_transaction` |
| Piggy Bank valuation | `piggy_bank_return_cash_transaction_id` is present | signed valuation delta applied to an existing Piggy Bank return | target Piggy Bank return cash transaction |

An ordinary Investment aggregate is not a Piggy Bank transaction. The show page must
not label every Investment as a Piggy Bank contribution or infer Piggy Bank semantics
from the built-in `INVESTMENT` category alone.

### Summary

The summary displays:

- description;
- kind badge (ordinary investment or Piggy Bank valuation adjustment);
- investment type;
- user bank account;
- exact date and reference month/year;
- entry value, formatted from cents;
- context-owned audit history link.

For a Piggy Bank valuation adjustment, the amount is labelled as an adjustment rather
than principal. The dashboard may also show the target return's projected total, but
that total must be calculated from the existing Piggy Bank return links and valuation
rows—not copied into a new persisted field.

### Relationships

For an ordinary investment:

- link the generated cash transaction when present;
- show the generated transaction's categories and entities as projection allocations;
- expose an exact investment-index aggregation link filtered by account and investment
  type;
- expose exact account and investment-type aggregation links where those destination
  screens exist.

For a Piggy Bank valuation adjustment:

- link the target Piggy Bank return cash transaction;
- show sibling valuation rows through an exact Investment index filter using
  `piggy_bank_return_cash_transaction_id`;
- never claim that the valuation row generated its own cash transaction.

Missing generated or target rows receive an explicit unavailable state. The show page
does not repair projections as a side effect of rendering.

### Actions

- Audit history
- Edit
- Duplicate, using the existing duplicate workflow and eligibility
- View related cash transaction/return when present
- Destroy only when the existing model callback and relationship guard permit it

## Subscription Dashboard

### Summary

The summary displays:

- description and comment;
- lifecycle status (`active`, `paused`, or `finished`);
- derived total (`cash_transactions.sum(:price) + card_transactions.sum(:price)`);
- current cash/card transaction counts;
- category and entity allocations;
- audit history.

Persisted counters and `price` are displayed as derived values, but the dashboard
query also computes relationship totals for consistency coverage. Rendering must not
mutate stale counters.

### Transaction Sections

Subscription transaction history is divided by relationship state, not by a guessed
description match:

1. **Open** — currently linked cash/card transactions whose `paid` value is false.
   Future and overdue unpaid records both remain open; the date badge distinguishes
   them.
2. **Paid history** — currently linked transactions whose `paid` value is true.
3. **Detached history** — context-owned cash/card transactions whose audit history
   proves they previously had this `subscription_id` and no longer do.

Detached history is read-only. It is derived from `AuditVersion` transitions involving
`subscription_id`; matching description, category, entity, amount, or date is never
sufficient. A detached record that still exists links to its current show page. A
destroyed historical record may be represented by its audit identity and last known
label, without fabricating a live link.

A transaction appears in only one section. A currently linked transaction wins over
any older detached transition. Rows are ordered newest first by effective date, then
type and ID for deterministic ties.

### Lifecycle Actions

Lifecycle buttons use a dedicated member transition boundary so a status-only change
cannot clear category/entity allocations or rewrite nested transactions:

| Current state | Offered transitions |
|---------------|---------------------|
| active | Pause, Finish |
| paused | Resume, Finish |
| finished | Reopen |

The transition endpoint permits only the target lifecycle event, locks the
Subscription, applies the corresponding status, and redirects to the approved
`return_to`. It does not call the general nested update path with missing allocation
parameters.

### Transaction Actions

- **Add transaction** opens the existing nested Subscription transaction workflow.
- **Attach existing** starts from a cash/card index filtered to eligible unowned
  transactions and preserves this dashboard as `return_to`; the existing bulk
  `add_to_subscription` endpoint performs the attachment.
- Each live row links to the correct CashTransaction or CardTransaction show page.
- Detached rows never offer edit-through-subscription controls.

### Destroy

Destroy is offered only when `subscription.can_be_destroyed?` is true. The server
continues to enforce the same rule. A Subscription with live transactions is not
destroyable, regardless of whether every transaction is paid. Detached-only history
does not block destruction because it is no longer a live dependent relationship.

## Existing Dashboard Hardening

Every `List`, `View all`, count, allocation, chart slice, and related-record action on
CashTransaction, CardTransaction, Budget, UserBankAccount, UserCard, Category, and
Entity dashboards must be inventoried and classified as one of:

- a direct record link to a show route;
- an exact filtered collection link;
- a safe mutation link;
- intentionally display-only.

### Exact Collection Rule

A collection link must be expressible as a stable server-side filter. The destination
must return all and only records represented by the source relationship. Preferred
filters are durable relationship keys:

- explicit record IDs for a finite calculated set;
- `user_bank_account_id` for account-owned cash records;
- `user_card_id` for card-owned card records;
- `category_id` or `entity_id` for allocation membership;
- `subscription_id` for live subscription membership;
- `reference_transactable_type` + `reference_transactable_id` for reference families;
- `piggy_bank_return_cash_transaction_id` for valuation siblings;
- exact month/year parameters only when the source claim is itself month-scoped.

Search text is not a relationship filter. A label copied into `search_term` is not an
acceptable substitute for an ID-based relationship.

When an existing index cannot express the relationship, KAKASHI-17 adds the smallest
explicit allowlisted filter or a dedicated read-only collection endpoint. Filter
parsing remains bounded by `Navigation::State`; arbitrary query hashes are rejected.

### Return Navigation

The generated collection URL includes a sanitized `return_to` pointing back to the
source show page. The filtered index stores that destination in its own navigation
context so edit, duplicate, bulk actions, and Back return through the same chain.
Context, active month/year, date range, source record ID, and sort are preserved only
when they are relevant to the claimed set.

## Out of Scope

- changing actionable-message send, receive, or auto-apply rules;
- repairing financial projections while rendering a dashboard;
- description-based reconstruction of detached subscription history;
- new Investment or Subscription accounting semantics;
- changing KAKASHI-18 merge planner/apply behavior;
- building a generic dashboard DSL before the two missing pages work.

