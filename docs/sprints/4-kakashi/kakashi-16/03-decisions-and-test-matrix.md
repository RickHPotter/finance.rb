# KAKASHI-16 Allocation Mutation: Decisions and Test Matrix

## Resolved Product Decisions

### D1. Does paid history lock every allocation change?

Decision: no. Paid history protects monetary/reference history, not descriptive
categorization by itself.

### D2. Does a safe paid-history allocation correction require confirmation?

Decision: no. If price, installment prices, installment structure, and reference
month/year remain unchanged, the correction saves directly and is audited.

### D3. Which non-allocation fields may accompany that correction?

Decision: description, comment, and date, provided the date change preserves the
persisted reference month/year for the transaction and every installment.

### D4. May an allocation payload bypass another historical guard?

Decision: no. Any price, installment, payment-state, account/card/reference, or
reference-period change leaves the safe envelope and uses the existing
confirmation/rejection contract.

### D5. What does bulk Add Entity create?

Decision: one neutral non-payer `EntityTransaction` with zero price, zero return, no
exchanges, and deterministic valid defaults.

### D6. Which entity row may bulk Remove delete?

Decision: only a neutral row. Non-payer status alone is insufficient; price, return,
and exchanges must also be zero/absent.

### D7. Which entity row may bulk Switch change?

Decision: only a neutral source row. Bulk switch never transfers monetary allocation,
payer responsibility, returns, exchanges, or friend identity.

### D8. How is a payer entity replaced?

Decision: through the normal transaction form by removing the old nested row and
adding/configuring the new row. Payer removal/switch is unavailable in the Bulk Action
Bar.

### D9. What happens when the bulk destination already exists?

Decision: add is a no-op. Switch removes the eligible source and retains the existing
destination row, creating no duplicate.

### D10. Are built-in structural categories generic bulk choices?

Decision: no. Their membership belongs to the owning Card/Investment/Subscription/
Exchange/Piggy Bank workflow. Ordinary custom allocations on the same owner may still
be corrected when the final structure remains valid.

### D11. Are built-in self or friend-backed entities generic bulk choices?

Decision: no. They are identity/structure boundaries and use the form/domain workflow.

### D12. What is the default apply behavior with conflicts?

Decision: strict and atomic. Ordinary Apply changes nothing when any selected owner has
a conflict.

### D13. May eligible rows still be applied?

Decision: yes, but only through a separate explicit `Apply eligible only` choice and
only when the planner proves those owners independent from every conflict.

### D14. Is eligible-only a best-effort row loop?

Decision: no. The approved eligible subset is itself applied atomically.

### D15. Which conflicts prevent eligible-only application?

Decision: any inseparable linked group, including exchanges, shared returns,
subscriptions, Piggy Banks, and generated projections.

### D16. What does selection count on cash/card indexes?

Decision: existing checkboxes select visible installment rows. Allocation planning
deduplicates their parent transaction IDs and preview reports both counts.

### D17. Does preview write anything?

Decision: no. No touches, recalculation, audit operation, or mutation is permitted.

### D18. How is preview protected from stale apply?

Decision: a signed actor/context/action/selection/result digest plus replan under
deterministic database locks.

### D19. Does a descriptive transaction allocation correction recalculate balances?

Decision: no. Monetary ledger inputs did not change. It refreshes allocation totals and
affected budget matching only.

### D20. What happens after a Budget allocation correction?

Decision: recompute matching/remaining values and run downstream balance recalculation
only if persisted budget balance inputs actually changed, beginning at the earliest
affected month.

### D21. How is an apply audited?

Decision: one KAKASHI-08 operation contains every allocation/coordinated version and
bounded metadata for action, mode, source/destination, and counts.

### D22. Are KAKASHI-16 allocation operations rollbackable?

Decision: yes, through the existing KAKASHI-08 V2 adapters and current-state conflict
checks, followed by the same impact recalculation.

### D23. Does KAKASHI-16 merge or destroy Category/Entity master records?

Decision: no. That is KAKASHI-18, which reuses this feature's foundation.

### D24. What happens to audit history during the enum-storage migration?

Decision: establish a one-time clean audit baseline. Incomplete legacy V1/V2
`AuditOperation` and `AuditVersion` rows are intentionally removed, and any Message
references to those operations are cleared without deleting the Messages. This is a
deployment migration, not a routine purge facility or a change to indefinite
retention for new audit operations. Append-only database protection remains enabled
after the reset.

### D25. How are the remaining numeric enums persisted?

Decision: `EntityTransaction.status` uses the strings `pending` and `finished`, while
`Exchange.exchange_type` uses `non_monetary` and `monetary`. Both columns have database
check constraints. Entity transaction status is derived state and is recomputed after
Exchange rollback instead of restoring a potentially stale audited value.

## Operation Matrix

| Action | Already satisfied | Ordinary eligible row | Structural/payer row |
| --- | --- | --- | --- |
| Add Category | no-op | create join | conflict when final family invalid |
| Remove Category | no-op when absent | destroy join | conflict when required/protected |
| Switch Category | no-op when same | replace/collapse destination | conflict when protected/invalid |
| Add Entity | no-op | create neutral row | conflict when owner invariant forbids addition |
| Remove Entity | no-op when absent | destroy neutral row | conflict |
| Switch Entity | no-op when same | change/remove neutral source | conflict |

## Safe Paid-History Matrix

| Submitted change | Expected result |
| --- | --- |
| custom category only | save without confirmation |
| neutral entity only | save without confirmation |
| payer removal/replacement through valid form workflow | save without paid-history confirmation |
| allocation plus description | save without confirmation |
| allocation plus comment | save without confirmation |
| allocation plus same-reference cash date | save without confirmation |
| allocation plus same-billing-reference card date | save without confirmation |
| allocation plus parent price | existing confirmation/rejection path |
| allocation plus installment price | existing confirmation/rejection path |
| allocation plus installment add/remove/reorder | existing guard |
| allocation plus reference month/year change | existing confirmation/rejection path |
| allocation plus user card/account/reference change | not in safe envelope |
| direct request imitating safe client state | server recomputes eligibility |

## Neutral Entity Matrix

| EntityTransaction state | Bulk add | Bulk remove | Bulk switch |
| --- | --- | --- | --- |
| absent | create neutral | no-op | no-op/conflict per source absence contract |
| neutral | no-op if destination | eligible | eligible |
| `is_payer: true` | destination-present no-op only | conflict | conflict |
| non-zero `price` | destination-present no-op only | conflict | conflict |
| non-zero `price_to_be_returned` | destination-present no-op only | conflict | conflict |
| has Exchanges | destination-present no-op only | conflict | conflict |
| friend-backed identity | protected | conflict | conflict |
| built-in self identity | protected | conflict | conflict |

## Structural Family Matrix

| Family | Generic category mutation | Generic entity mutation | Rich form/domain path |
| --- | --- | --- | --- |
| ordinary transaction | custom categories allowed | neutral-only bulk | full validated nested form |
| Card Payment | generated category protected | generated structure protected | source card workflow |
| Card Installment invoice | generated category protected | generated structure protected | source card workflow |
| Card Advance | generated category protected | generated structure protected | advance workflow |
| Investment aggregate | generated category protected | generated structure protected | Investment workflow |
| Subscription | inherited allocation protected | inherited allocation protected | Subscription workflow |
| Exchange source | custom descriptive only if final state valid | neutral-only if identity unaffected | exchange entity sheet/domain |
| Exchange/Borrow Return | built-ins protected | linked identities protected | shared-return domain |
| Piggy Bank source/return | built-ins protected | one-entity group protected | Piggy Bank domain |
| failed return | failure built-in protected | linked return structure protected | recovery/report workflow |

## Preview and Apply Matrix

| Preview result | Strict Apply | Apply eligible only |
| --- | --- | --- |
| all eligible | enabled | hidden |
| eligible plus no-ops | enabled | hidden |
| no changes required | disabled | hidden |
| eligible plus independent conflicts | disabled | explicitly available |
| eligible plus inseparable structural conflict | disabled | unavailable |
| all conflict | disabled | unavailable |
| stale after preview | rejected and re-preview required | rejected and re-preview required |

## Selection Matrix

| Scenario | Expected result |
| --- | --- |
| one transaction installment selected | one row, one owner |
| three installments of same transaction selected | three rows, one owner |
| installments from two transactions selected | row count and two unique owners |
| duplicate parent ID in payload | deduplicated server-side |
| cash and Budget rows mixed | prevented by selection-kind boundary |
| foreign-context owner ID | not found/rejected |
| hidden/filtered row becomes deselected | excluded from payload |
| existing pay action | still receives installment IDs |
| allocation action | receives unique parent record IDs |

## Category Service Matrix

| Scenario | Expected result |
| --- | --- |
| add missing custom category | eligible |
| add existing category | no-op |
| remove present custom category | eligible |
| remove absent category | no-op |
| switch to missing destination | replace |
| switch with destination present | remove source, retain destination |
| same source/destination | no-op |
| inactive source/destination | conflict |
| foreign-user category | rejected |
| structural built-in selection | rejected/protected |
| ordinary custom beside protected built-in | eligible if final family valid |
| final invalid category family | conflict |

## Entity Service Matrix

| Scenario | Expected result |
| --- | --- |
| add absent ordinary entity | neutral row created |
| add existing entity | no-op |
| remove neutral entity | eligible |
| remove payer/non-zero/exchange row | conflict with form guidance |
| switch neutral source | eligible |
| switch neutral source to existing destination | source removed, destination unchanged |
| switch payer/non-zero/exchange source | conflict |
| built-in self source/destination | protected |
| friend-backed source/destination | protected |
| Piggy Bank entity mutation | conflict unless rich domain workflow |
| foreign-user entity | rejected |

## Budget Matrix

| Scenario | Expected result |
| --- | --- |
| category-only budget remains nonempty | eligible |
| entity-only budget remains nonempty | eligible |
| remove final allocation | conflict |
| add existing BudgetCategory/BudgetEntity | no-op |
| switch to existing destination | collapse duplicate |
| inclusive final pair duplicates another budget | conflict |
| exclusive final category/entity duplicates another budget | conflict |
| multiple selected months | each planned; earliest changed month drives required balance recalculation |
| embedded cash-index Budget selection | same service and result as Budgets index |

## Audit and Rollback Matrix

| Scenario | Expected result |
| --- | --- |
| preview | no AuditOperation/version |
| strict apply | one operation |
| eligible-only apply | one operation with mode metadata |
| category add/remove/switch | CategoryTransaction/BudgetCategory versions grouped |
| entity add/remove/switch | EntityTransaction/BudgetEntity versions grouped |
| coordinated form projection write | same operation with mutation source metadata |
| rejected/stale apply | no committed financial versions |
| rollback preview | allocation key/current-state conflicts reported |
| rollback apply | original allocations restored atomically |
| rollback recalculation | counters/budgets/projections refreshed |
| 2026-07-30 deployment baseline | incomplete legacy V1/V2 history cleared once; subsequent operations retained |

## Recalculation Matrix

| Change | Required work |
| --- | --- |
| transaction custom category | category totals + affected budget matching |
| transaction neutral entity | entity totals + affected budget matching |
| same-reference description/comment/date | no financial balance recalculation |
| Budget criteria | recompute matching and remaining value |
| Budget persisted balance input changed | recalculate from earliest affected month |
| coordinated structural form change | domain projection sync plus declared recalculation |
| rollback | same before/after impact registry |

## Request and Security Matrix

| Scenario | Expected result |
| --- | --- |
| valid current-context selection | preview/apply allowed |
| foreign-context owner | not found/rejected |
| foreign-user category/entity | not found/rejected |
| inactive destination | conflict |
| tampered token | rejected |
| expired token | rejected |
| another actor's token | rejected |
| another context's token | rejected |
| changed allocation after preview | stale preview |
| concurrent applies | deterministic lock/no partial write |
| Turbo apply | bounded row/index fragments; URL retained |
| non-Turbo apply | `303` to validated index state |
| unsafe `return_to` | canonical index fallback |

## Manual Verification Matrix

| Scenario | Expected result |
| --- | --- |
| paid cash form custom category correction | saves directly |
| paid card form same-reference date plus allocation | saves directly |
| paid form price/reference change | existing warning/rejection remains |
| payer entity visible in bulk preview | conflict with form guidance |
| payer entity removed/replaced in valid form | succeeds with structure intact |
| mixed 8 eligible/2 payer conflicts | strict disabled; explicit eligible-only changes 8 |
| linked structural conflict | eligible-only unavailable |
| repeated installments selected | preview shows rows versus unique transactions |
| desktop/mobile/PWA | actions and preview usable |
| dark/light mode | modal, combobox, conflicts, and row refresh readable |
| English/Portuguese | labels and reason codes localized |
| audit history | one understandable grouped operation |
| rollback | preview/apply restores allocations and derived displays |

## Remaining Product Decisions

There are no blocking V1 product decisions. A structural family not listed here must
default to conflict until its invariants and domain coordinator are explicitly covered;
it must not be treated as ordinary merely because a current callback happens to permit
the write.
