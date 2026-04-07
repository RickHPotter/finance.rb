# JIRAIYA-04: `reference_transactable` Chain Normalization

## Outcome Target

`CashTransaction.reference_transactable` should stop meaning different things in
different flows.

The target rule is:

- `reference_transactable` always points to the immediate parent transaction in the
  shared exchange chain
- the chain should be explicit enough that runtime code no longer has to guess the
  sender-side or receiver-side counterpart from structure alone

This is a normalization project, not only a small controller cleanup.

## Current Problem

Today the app mixes at least four meanings into the same polymorphic field:

- sender-side source link
- receiver-side mirror link
- normalized canonical shared-return link
- historical fallback link

That overload leaks into:

- actionable message create/update replay
- destroy notification resolution
- shared paid-state synchronization
- audit and backfill tooling

The result is that several flows only work because the app tries multiple guesses in
sequence until one resolves.

## Canonical Parent-Chain Contract

### Shared-return chain for card-origin or reimbursement flows

1. sender `EXCHANGE` source
   - `CardTransaction` or `CashTransaction`
   - `reference_transactable = nil`
2. sender `EXCHANGE RETURN`
   - `reference_transactable = sender source`
3. receiver `BORROW RETURN`
   - `reference_transactable = sender EXCHANGE RETURN`

This is the three-node chain we want for:

- `EXCHANGE CardTransaction`
- `EXCHANGE CashTransaction` with reimbursement intent

Important nuance:

- a single sender source can legitimately have multiple sender-side `EXCHANGE RETURN`
  children
- this happens in split exchanges, for example one source transaction with multiple
  friend-linked payer/entity slices
- in those cases every sender-side `EXCHANGE RETURN` should point to the same sender
  source
- the operator choice in audit only decides which sender-side `EXCHANGE RETURN`
  anchors the receiver-side node for a given assistant-message family

### Loan chain for cash-origin loan flows

1. sender `EXCHANGE`
   - `reference_transactable = nil`
2. sender `EXCHANGE RETURN`
   - `reference_transactable = sender EXCHANGE`
3. receiver `EXCHANGE`
   - `reference_transactable = sender EXCHANGE RETURN`
4. receiver `EXCHANGE RETURN`
   - `reference_transactable = receiver EXCHANGE`

This keeps the entire multi-user flow as one explicit directed chain instead of a set
of partial shortcuts back to the original source.

## Why This Contract Helps

- the parent of each transaction becomes deterministic
- the runtime can walk the chain instead of guessing by categories or dates first
- audits and repair runners can express intended changes as edge rewrites
- future UI can explain the flow as a sequence of linked records instead of a set of
  inferred counterparts

## Message Contract Impact

Normalizing transaction references is not enough by itself.

Current actionable message logic still assumes direct one-hop resolution from the
message payload to the receiver-local transaction.

That means the runtime must evolve together with the chain contract.

### Create / Update

- replay payload can still identify the originating business event
- local target resolution must become chain-aware
- receiver-side lookup may need to resolve descendants of the source, not only direct
  `reference_transactable` matches

### Destroy

- destroy should no longer depend on a direct `find_by(reference_transactable: source)`
  assumption
- destroy resolution must either:
  - carry the explicit local target, or
  - resolve the affected descendant chain deterministically

### Paid-state

- counterpart sync must stop assuming that the counterpart is always the direct reverse
  reference
- sync helpers need explicit traversal helpers for parent, child, root, and chain role

## Runtime Helpers To Introduce

The runtime should move away from ad hoc controller/model guesses and toward explicit
chain navigation helpers.

Suggested helpers:

- `reference_parent`
- `reference_root`
- `reference_children`
- `shared_exchange_chain`
- `shared_exchange_role`
- `local_reference_for_message`

The important rule is that these helpers should express chain semantics directly
instead of embedding message-specific fallback guesses in multiple places.

## Audit / Apply Strategy

### Step 1: Chain audit

Audit every exchange/shared-return family and report:

- current chain nodes
- current reference edge on each node
- expected reference edge on each node
- missing nodes
- edge mismatches

The admin settings screen should become the visual review surface for this.

### Step 2: Edge rewrite runner

Apply runners should only rewrite reference edges at first.

That means:

- set source references to `nil`
- point sender `EXCHANGE RETURN` to sender source
- point receiver `BORROW RETURN` to sender `EXCHANGE RETURN`
- point receiver loan `EXCHANGE` to sender `EXCHANGE RETURN`
- point receiver loan `EXCHANGE RETURN` to receiver `EXCHANGE`

### Step 3: Runtime write-path migration

After the data is auditable and rewritable:

- update create/update flows to write the canonical edge immediately
- update destroy/paid-state/message resolution to traverse the chain
- remove now-redundant shared-return normalization hacks

## Compatibility Rule

Until the backfill and runtime migration are complete:

- the app must continue to read legacy direct-to-source links
- the app should stop writing new legacy links as soon as the runtime helpers are ready

That means the rollout is:

1. read legacy + canonical
2. audit and rewrite old data
3. write canonical only
4. remove legacy-only fallback paths later

## First Development Slice

The first slice should not mutate business behavior yet.

It should:

- document the contract
- teach the audit to show current vs canonical edges
- use the settings audit UI as the operator review surface

Only after that should the runtime write/read paths be migrated.
