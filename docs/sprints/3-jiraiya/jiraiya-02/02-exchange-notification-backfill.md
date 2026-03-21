# JIRAIYA-02 Slice 7: Exchange Notification Full Backfill

## Goal

We have two cash-side exchange notification use cases between Rikki and Gigi:

1. `loan`
   - sender creates an `EXCHANGE`
   - receiver should mirror the classic exchange flow

2. `reimbursement`
   - sender creates an `EXCHANGE`, but the real meaning is "I paid your part now"
   - receiver should start from a reimbursement-oriented flow, closer to `BORROW RETURN`

The current `FriendNotifiable` payload only supports one meaning for cash-side exchange notifications, so historical records and future records need to be normalized.

Because this affects only two users, we are choosing a **full backfill** instead of a forward-only compatibility layer.

## Constraints

- Do not mutate historical data blindly.
- Preserve an audit trail of each source transaction before rewriting anything.
- The migration unit is the original sender-side `CashTransaction`.
- Receiver-side mirrored transactions must stay linked through `reference_transactable`.
- `messages.headers` are part of the backfill surface because they drive the create/edit actions in chat.

## Backfill Strategy

### Step 1: Read-only audit

Build a report of all historical exchange-root cash transactions between Rikki and Gigi.

Each audit case must include:

- source sender-side cash transaction
- counterpart user and counterpart entity
- receiver-side local reference transaction, if it exists
- conversation messages linked to the case
- latest active `message.headers` payload
- structural differences between the latest snapshot and the receiver-side local transaction
- a manual classification slot

This step must be completely non-destructive.

### Step 2: Manual classification

Review each audited case and classify it as one of:

- `loan`
- `reimbursement`

This classification should be stored in a separate mapping file keyed by the sender-side source transaction id.

Suggested shape:

```json
{
  "123": "loan",
  "456": "reimbursement"
}
```

### Step 3: Introduce the new payload contract

Update future exchange notifications so cash-side friend notifications carry an explicit intent.

Target payload families:

- `cash_exchange_v2.loan`
- `cash_exchange_v2.reimbursement`

At this stage, new records should stop relying on the old implicit semantics.

### Step 4: Backfill messages and local receiver records

For each classified historical source transaction:

- rewrite `messages.headers` to the new intent-aware payload shape
- rewrite the receiver-side local cash transaction to the correct semantic target
- rewrite related entity/exchange structures if the intent requires it
- keep `reference_transactable` links intact

This step must be:

- idempotent
- dry-run capable
- scoped only to the Rikki/Gigi relationship

### Step 5: Verification

For every migrated case, verify:

- chat `Create` opens the correct form semantics
- chat `Edit` still replays the original snapshot correctly
- the receiver-side transaction category and signs match the intended meaning
- totals, exchanges, and linked cash transactions remain coherent

## Technical Notes

### Why the audit is rooted on sender-side transactions

Receiver-side mirrored transactions are already derived data. Using them as the migration root would make it harder to distinguish:

- original sender intent
- local receiver edits
- stale message snapshots

The source sender-side `CashTransaction` is the stable event we can use to gather the whole historical thread.

### Why `messages.headers` must be backfilled

The chat create/edit actions do not rebuild themselves from current domain state alone. They replay the payload from `message.headers`. If those headers keep the old shape, the UI will continue offering the wrong transaction semantics even after local records are corrected.

### Why we are not auto-classifying

Even with only two users, intent is not reliably inferable from prices and signs alone. The safe approach is:

1. inventory every case
2. review each case
3. apply a deliberate mapping

## Development Order

1. Add the read-only audit service.
2. Add the rake task that exports the audit report.
3. Run the audit and inspect the report.
4. Generate the classification mapping scaffold.
5. Review and edit the mapping manually.
6. Run the header backfill in `DRY_RUN=true` mode.
7. Run the header backfill for real.
8. Implement the new payload contract for future notifications.
9. Verify every migrated case in the UI.

## Initial Command

The first command in this slice should stay read-only:

```bash
bin/rails exchange_backfill:audit USER_A=rikki USER_B=gigi OUTPUT=tmp/exchange_backfill_audit.json
```

After the audit is reviewed, generate the mapping scaffold:

```bash
bin/rails exchange_backfill:seed_mapping INPUT=tmp/exchange_backfill_audit.json OUTPUT=tmp/exchange_backfill_mapping.json
```

Then apply the reviewed mapping in dry-run mode first:

```bash
bin/rails exchange_backfill:apply USER_A=rikki USER_B=gigi MAPPING=tmp/exchange_backfill_mapping.json DRY_RUN=true OUTPUT=tmp/exchange_backfill_apply.json
```
