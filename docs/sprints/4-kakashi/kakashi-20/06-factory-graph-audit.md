# KAKASHI-20 Factory Graph Audit

## Scope

This audit covers the high-volume financial factories named in Slice 3. It records
which persisted graph is required by the domain and which setup must be requested by
an explicit trait or factory call.

| Factory | Minimal default graph | Optional or derived work | Decision |
| --- | --- | --- | --- |
| `user` | User plus canonical records created by model callbacks | Random identity data | Retain the canonical callback graph; seed random traits per example. |
| `context` | Context and its user | Source snapshots and financial rows | Retain the association only; cloning belongs to service setup. |
| `cash_transaction` | Account, context, and one cash installment | Allocations, exchanges, projections, and messages | Retain the required installment; request every other branch explicitly. |
| `card_transaction` | Card, context, and one card installment | Category/entity allocations, exchanges, projections, and messages | Remove allocations from the default and expose them through `:with_allocations`. |
| `cash_installment` / `card_installment` | The installment row | Parent transaction and payment workflows | Retain standalone defaults; parent factories build the required child. |
| `category_transaction` / `entity_transaction` | Allocation and a valid transactable | Additional allocations and exchange rows | Direct factory usage intentionally creates a valid graph; callers with a transaction pass it explicitly. |
| `exchange` | Exchange and its owning entity allocation | Return projections and messages | Retain the valid owner; projection behavior belongs to service/request setup. |
| `investment` | Account, type, context, and investment | Cash projections and piggy-bank returns | Retain valid foreign keys; projections remain callback/service behavior. |
| `budget` | Budget and one category allocation | Entity allocations and bulk mutation graphs | Retain the existing valid budget shape; revisit only with dedicated budget-factory coverage. |
| messages | No standalone factory | Messages arise from the production workflows under test | Continue creating them through those workflows so sender/receiver rules remain covered. |

## Determinism Contract

- Association reuse resolves the lowest database ID instead of choosing an arbitrary
  record.
- Polymorphic helper defaults resolve the first model family listed by the caller.
- Each example derives Ruby and Faker randomness from the suite seed plus the stable
  RSpec example ID.
- Traits named `:random` remain useful for varied data, but the same example and suite
  seed now reproduce the same values and validation branches.

## Migration Result

Consumers that inspect CardTransaction allocations now opt into `:with_allocations`.
Consumers concerned only with installments, references, navigation, or other financial
behavior no longer pay for unrelated category and entity rows. Executable helper specs
protect both the minimal default and the opt-in graph.

No `create` call was converted to `build` or `build_stubbed` in this slice: the audited
service and request examples exercise persistence, callbacks, database constraints,
or associations whose behavior would change under an in-memory substitute.
