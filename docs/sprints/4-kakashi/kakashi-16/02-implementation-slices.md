# KAKASHI-16 Allocation Mutation: Implementation Slices

## Delivery Rules

- Keep each slice independently reviewable and conventionally committed.
- Run `bin/rubocop -A` after every edit batch.
- Add focused model/service/request coverage in the slice that introduces behavior.
- Do not bypass callbacks with raw bulk SQL unless `Audit::BulkMutation` explicitly
  records the change and the impact registry performs all required recalculation.
- Preview is always read-only.
- Apply always replans under lock.
- Paid-history allocation changes never bypass price/installment/reference guards.
- Bulk entity actions remain neutral-only; payer changes remain form-only.
- Preserve KAKASHI-15 canonical URL/index state.

## Slice 1: Characterization and Allocation Policy Primitives

Capture the old blanket lock and introduce operation vocabulary without changing user
behavior.

Deliver:

- shared allocation action/value objects for add/remove/switch and category/entity
- owner adapters for CashTransaction, CardTransaction, and Budget
- normalized planner outcome (`eligible`, `noop`, `conflict`) and reason codes
- neutral `EntityTransaction` predicate
- structural-family classifier
- before/after impact object
- characterization coverage for current paid-history lock, Subscription bypass,
  generated families, payer entities, and budget joins

Suggested commit:

```text
feat: define allocation mutation policy
```

## Slice 2: Safe Paid-History Form Envelope

Replace the blanket allocation lock with field-aware safety.

Deliver:

- allocation policy integration in `HasFinancialSafetyRules` and
  `HasFinancialSafetyGuards`
- safe envelope for allocation plus description/comment/same-reference date changes
- persisted versus proposed transaction and installment reference comparison
- unchanged price and installment-price enforcement
- direct-request protection
- no extra confirmation for accepted allocation-only/same-reference corrections
- existing confirmation/rejection behavior retained outside the envelope

Coverage:

- paid and partially paid cash/card transactions
- category-only and neutral/entity nested changes
- description/comment combined with allocation
- cash date change in same reference month/year
- card date change in same billing reference
- date crossing reference period
- parent or installment price change
- installment add/remove/reorder
- hidden card/account/reference changes

Suggested commit:

```text
feat: allow safe paid allocation corrections
```

## Slice 3: Normal-Form Entity and Structural Coordination

Keep the normal form as the rich workflow for entity allocations.

Deliver:

- payer removal remains available through nested cash/card forms
- payer replacement is represented as old-row removal plus configured new row
- allocation service mode that receives full nested entity attributes
- exchange/shared-return/Piggy Bank/Subscription coordination delegated to explicit
  domain services
- structural category protection based on final state
- detailed stacked failures for invalid domain outcomes

Coverage:

- remove/add ordinary payer allocation without changing transaction total/reference
- exchange-bearing payer validation
- friend-backed entity authorization/counterpart protection
- Piggy Bank source/return entity invariant
- Subscription-owned allocation synchronization
- direct parameter attempts that omit required coordinated data

Suggested commit:

```text
feat: coordinate form entity corrections
```

## Slice 4: Category Bulk Planner and Mutator

Implement Add, Remove, and Switch Category at the service layer.

Deliver:

- category source/destination ownership and active-state validation
- custom-category eligibility
- built-in structural exclusion from generic bulk choices
- idempotent add/remove/switch
- destination-present duplicate collapse
- final category-family validation
- CashTransaction, CardTransaction, and Budget category adapters
- impact collection for counters and budgets

Coverage:

- source present/absent
- destination present/absent
- source equals destination
- duplicate joins
- inactive/foreign/built-in categories
- ordinary custom category beside protected built-in
- generated and Subscription-owned conflicts
- paid-history owners
- budget missing-allocation and uniqueness conflicts

Suggested commit:

```text
feat: add bulk category mutation services
```

## Slice 5: Neutral Entity Bulk Planner and Mutator

Implement the locked neutral-only bulk entity contract.

Deliver:

- neutral entity add defaults
- neutral-only remove and switch
- payer/non-zero/return-bearing/exchange-bearing conflicts
- built-in self and friend-backed identity protection
- idempotent destination-present collapse
- CashTransaction, CardTransaction, and Budget entity adapters
- final owner invariant validation

Coverage:

- neutral add/remove/switch
- existing destination
- payer source
- zero-price payer flag inconsistency
- non-zero price
- non-zero return
- exchanges
- MOI and friend-backed entity
- Piggy Bank one-entity rule
- generated, Exchange, shared-return, and Subscription groups
- paid-history owners
- budget joins and uniqueness

Suggested commit:

```text
feat: add neutral entity bulk mutations
```

## Slice 6: Preview, Token, Locking, and Apply

Create the common server workflow before adding index controls.

Deliver:

- preview route/controller/service
- localized grouped counts and reasons
- signed actor/context/action/selection/result digest
- strict apply endpoint
- explicit eligible-only apply mode
- independence classifier for partial application
- deterministic lock order and replan-under-lock
- stale-preview rejection
- one transaction and one root audit operation per apply
- Turbo and non-Turbo responders

Coverage:

- read-only preview
- selected-row versus unique-owner counts
- all eligible
- eligible plus no-op
- eligible plus independent conflicts
- inseparable structural conflicts
- strict apply unavailable with conflicts
- explicit eligible-only subset
- expired/tampered/foreign token
- allocation drift between preview/apply
- concurrent apply and idempotent retry behavior

Suggested commit:

```text
feat: preview and apply allocation changes
```

## Slice 7: Shared Bulk Allocation Interface

Build the modal/action UI shared by the three indexes.

Deliver:

- six actions: Add/Remove/Switch Category and Add/Remove/Switch Entity
- source/destination comboboxes with protected options omitted
- selection payload using parent record IDs for allocation actions
- preview summary with selected rows, unique records, affected, no-op, and conflicts
- record links and grouped localized reasons
- strict confirmation button
- separate eligible-only confirmation button when permitted
- loading, stale, empty, success, and failure states
- responsive desktop/mobile/PWA layout and dark mode

Coverage:

- keyboard and screen-reader labels
- mobile modal/sheet behavior
- correct button enablement
- no apply without preview token
- eligible-only button visibility
- selection retained when preview closes
- selection reset/row refresh after success

Suggested commit:

```text
feat: add allocation bulk action interface
```

## Slice 8: Cash and Card Index Integration

Attach allocation actions to installment-oriented transaction indexes.

Deliver:

- reuse existing checkboxes without changing payment/transfer semantics
- allocation action payload deduplicated by `bulk_record_id`
- selected installment-row and unique-transaction counts
- current-context owner loading
- preserved search/card/month/sort state
- affected transaction/month fragment refresh
- updated category colour/entity presentation after apply

Coverage:

- repeated installments of one parent selected
- mixed parents and months
- cash and selected-card indexes
- paid/unpaid mixtures
- existing pay/partial-pay/transfer/subscription actions remain unchanged
- Turbo success keeps canonical index URL
- non-Turbo Post/Redirect/Get

Suggested commit:

```text
feat: bulk edit transaction allocations
```

## Slice 9: Budget Index Integration

Add the same allocation actions to budget selection.

Deliver:

- category/entity actions on Budget selection kind
- coexistence with current inclusivity/installment/destroy bulk actions
- final budget validation
- matching/remaining-value refresh
- cash-index embedded Budget rows use the same contract
- earliest-month downstream recalculation only when persisted budget balance inputs
  change

Coverage:

- budgets index and cash-index embedded budgets
- inclusive/exclusive budgets
- category-only, entity-only, and combined criteria
- destination duplicate
- missing final allocation
- same-month uniqueness conflicts
- multiple selected months
- selection-kind separation from transaction actions

Suggested commit:

```text
feat: bulk edit budget allocations
```

## Slice 10: Audit, Rollback, Recalculation, and Hardening

Prove operational correctness and close the feature.

Deliver:

- bounded KAKASHI-08 operation metadata
- all coordinated writes grouped under the apply operation
- rollback preview/apply coverage for all four allocation-row types
- consolidated category/entity counter refresh
- affected-budget recomputation registry
- proof that descriptive transaction allocation changes do not run balance
  recalculation
- structural form workflow recalculation assertions
- Bullet/query review, localization completion, and obsolete blanket-lock cleanup
- final dependency seam documented for KAKASHI-18

Final verification:

```sh
bin/rspec spec/models spec/concerns spec/requests
bin/rspec spec/services
yarn build
bin/ci
```

Suggested commit:

```text
spec: harden allocation mutation workflows
```

