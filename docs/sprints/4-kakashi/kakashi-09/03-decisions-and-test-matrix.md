# KAKASHI-09 Health Check: Decisions and Test Matrix

## Resolved Product Decisions

### D1. Is Health Check a renamed Settings page?

Decision: no. `/healthcheck` is a registry-backed operational workspace with a
summary/run/detail/repair contract. `/settings` is only a temporary redirect.

### D2. Is this the same as Rails `/up`?

Decision: no. `/up` reports process availability. Health Check reports current
application and financial-data integrity.

### D3. Who can access the workspace?

Decision: administrators only. Authenticated non-admin users receive `404`, and the
navigation item is hidden from them.

### D4. What happens to ordinary-user audit history?

Decision: nothing changes. KAKASHI-08 history remains owner-readable through its
existing routes. The Health Check link to audit history is an administrator
convenience, not the authorization boundary for history.

### D5. What data does an administrator inspect?

Decision: the signed-in administrator's selected context. This is not a global
all-users console.

### D6. How are connected users handled?

Decision: Exchange Trio and misplaced-intent checks inspect relationships connected to
the current administrator and selected scenario. They may cover all such connections
or one explicitly validated connected user. Context-only checks ignore that filter.

### D7. Which checks ship in V1?

Decision:

- `exchange_trio`
- `exchange_return`
- `card_exchange_projection`
- `misplaced_exchange_intent`
- `piggy_bank`

Piggy Bank is deliberately added to the original outline because the current Settings
surface already exposes that integrity audit and removing it would regress operator
visibility.

### D8. Are Exchange Trio and canonical reference-chain health separate checks?

Decision: no. Canonical reference-chain analysis is a capability within
`exchange_trio`. Keeping one stable check avoids duplicate scans and duplicate
failures for the same exchange family.

### D9. Are future checks shown as unavailable placeholders?

Decision: no. Reference/invoice and balance-projection checks enter the registry only
when they have an actual runner. `unavailable` reports a real current execution or
scope problem.

### D10. Are checks synchronous?

Decision: no. Solid Queue runs one job per check. Run all enqueues independent jobs so
one failure cannot block the others.

### D11. What is persisted?

Decision: only the latest execution state, outcome, counts, timestamps, duration, and
sanitized error code for each scope. Financial finding payloads and diagnostic-run
history are not persisted.

### D12. Why not persist finding snapshots?

Decision: Health Check reports current integrity, while KAKASHI-08 stores durable
mutation history. Persisting financial detail snapshots would duplicate sensitive
data, create a second retention policy, and complicate pagination and authorization.

### D13. What does the first visit do?

Decision: it is read-only. Never-run checks display as unavailable with a reason. The
administrator explicitly chooses Run all or an individual run.

### D14. How are execution and health represented?

Decision: execution state is queued/running/completed/unavailable. Completed outcome
is healthy/warning/failing. The UI maps queued and running to the visible Running
summary.

### D15. How is a mixed result classified?

Decision: any failure makes the check failing. Warnings produce warning only when
there are no failures. Zero warning/failure findings produces healthy. An execution
error produces unavailable.

### D16. Are details snapshots of the last run?

Decision: no. Details are lazy live diagnostics. The UI shows both the last summary
time and the live detail time and offers rerun when they differ.

### D17. How is pagination bounded?

Decision: 25 rows by default and 100 maximum, with stable record-ID tiebreakers.
Providers should query only the requested page where the domain algorithm permits.

### D18. Which repairs ship in V1?

Decision: only existing capabilities, extracted and hardened:

- canonical reference-chain correction
- Exchange Return allocation percentage/value correction
- card-bound exchange projection correction
- misplaced loan-to-reimbursement conversion

Piggy Bank and unsupported finding types remain diagnostic-only.

### D19. Is there a Repair all action?

Decision: no. Run all never mutates data. Every V1 repair targets one reviewed
finding.

### D20. Is preview optional for a small repair?

Decision: no for repairs initiated from Health Check. Every Health Check structural
correction requires a read-only preview, explicit confirmation, a signed token, and
current-state revalidation.

The existing owner-authorized cash-transaction card-projection fix remains outside
Health Check as the sole V1 exception. It continues to use the extracted repair service
and ordinary KAKASHI-08 web auditing without becoming administrator-only.

### D21. How are stale previews handled?

Decision: reject them. Apply never overwrites a graph that diverged after preview.

### D22. What proves that a repair worked?

Decision: the affected check reruns after commit. A successful mutation notice does
not itself make the check healthy.

### D23. How is a repair audited?

Decision: one KAKASHI-08 operation with root source `admin_repair`, bounded Health
Check metadata, and a result link to the operation history.

### D24. Does Naming Convention count as a health check?

Decision: no. It is an administrator-only maintenance tool with preview and audited
apply, visually and numerically separate from integrity status.

### D25. Where do backup and recalculation belong?

Decision: backup stays where it is in V1. No generic recalculation action is exposed
until it has its own safety contract.

### D26. What happens to `naming-tabs`?

Decision: replace the misleading name with a neutral reusable lazy-tabs concept and
update every consumer, including balances.

## Registry and Result Test Matrix

| Scenario | Expected result |
| --- | --- |
| registered stable key | registry entry resolves |
| unknown stable key | no entry and route returns `404` |
| translated title changes | persisted key and URLs remain unchanged |
| negative result count | validation failure |
| noninteger result count | validation failure |
| missing count | normalized to zero |
| failure and warning findings | outcome is failing |
| warning-only findings | outcome is warning |
| no warning/failure findings | outcome is healthy |
| adapter exception | outcome not fabricated; execution unavailable |
| result contains Active Record object | contract rejects it |
| Piggy Bank registry lookup | registered as diagnostic-only |
| future unimplemented check | absent rather than placeholder-unavailable |

## Persistence Test Matrix

| Scenario | Expected result |
| --- | --- |
| first result for check/user/context | latest row created |
| rerun same null-connected scope | same latest row updated |
| same check with selected connected user | independent latest row |
| same check in another context | independent latest row |
| two null connected-user inserts race | unique constraint leaves one scope row |
| result counts contain raw finding data | validation/serializer excludes it |
| error contains long/internal exception detail | bounded sanitized code only |
| financial model changes | Health Check row is not versioned |
| latest row updated | no KAKASHI-08 financial history noise |

## Authorization and Scope Test Matrix

| Scenario | Expected result |
| --- | --- |
| unauthenticated `/healthcheck` | Devise authentication flow |
| non-admin `/healthcheck` | `404` |
| non-admin check/run/preview/apply route | `404` |
| owning non-admin direct card-projection fix | remains available outside Health Check |
| admin `/healthcheck` | `200` |
| non-admin navigation | no Health Check item |
| admin navigation | Health Check item points to `/healthcheck` |
| ordinary user audit-history route | existing KAKASHI-08 owner scope preserved |
| submitted context belongs to another user | `404` |
| selected context is archived or missing | controlled unavailable/not-found behavior |
| submitted connected user is unrelated | `404` |
| context-only check with connected filter | filter does not broaden/change its reads |
| Exchange Trio in derived scenario | only matching scenario conversation graph |
| Exchange Trio row from another context | excluded |
| connected-user filter selected | only that validated pair |
| no connected-user filter | all current administrator connections, no unrelated users |

## Routing Test Matrix

| Scenario | Expected result |
| --- | --- |
| `GET /healthcheck` | canonical dashboard |
| `GET /settings` | temporary redirect to `/healthcheck` |
| follow `/settings` as non-admin | canonical route returns `404` |
| `GET /up` | existing Rails health behavior unchanged |
| old admin settings audit route | removed after parity |
| unknown check route | `404` |
| unknown repair route | `404` |
| generated frame/DOM IDs | `healthcheck_*`, not `settings_*` |
| browser refresh on check detail | canonical Health Check URL and scope retained |

## Dashboard Test Matrix

| Scenario | Expected result |
| --- | --- |
| no checks have run | five unavailable/never-run cards |
| all checks healthy | healthy total five |
| one warning, one failing | summary counts each independently |
| one queued and one running | both included in visible running total |
| one unavailable | overall view does not imply fully healthy |
| selected context changes | different latest execution rows displayed |
| selected connected user changes | pair-check results switch; context-only results remain scoped to context |
| dashboard loads | no audit detail service called |
| Run all button rendered | diagnostic wording; no repair implication |
| check has no repair capability | read-only label and explanation |
| last run has duration | formatted duration and timestamp displayed |
| long context/user name | wraps without breaking controls |

## Asynchronous Execution Test Matrix

| Scenario | Expected result |
| --- | --- |
| Run one | one queued latest row and one job |
| Run all | one job per eligible registered check |
| check already queued/running | duplicate request does not enqueue duplicate work |
| job starts | matching generation becomes running |
| job completes | completed outcome/counts/timing persisted |
| job raises | matching generation becomes unavailable |
| one Run all job fails | other jobs still complete independently |
| rerun starts before old job finishes | old generation cannot overwrite new result |
| admin flag removed before job | unavailable authorization reason |
| context removed/archived before job | unavailable scope reason |
| connected relationship removed before job | pair check unavailable; no unrelated fallback |
| broadcast emitted | only matching signed user/context/connection stream updates |
| job error logged | server receives diagnostics; UI receives sanitized code |

## Check Normalization Test Matrix

### Exchange Trio

| Scenario | Expected result |
| --- | --- |
| complete trio and canonical references | healthy |
| topology issue | failure finding |
| supported reference mismatch | failure plus per-row repair capability |
| ambiguous middle/receiver candidate | failure with unavailable reason |
| unrelated user's conversation | excluded |
| matching user but other scenario | excluded |
| selected connected user | only selected pair counted |

### Exchange Return

| Scenario | Expected result |
| --- | --- |
| no audit rows | healthy |
| installment total mismatch | failure, read-only unless a repair exists |
| source allocation mismatch with safe choice | failure, repairable per row |
| paid-history implication | explicit warning/unavailable action reason |
| paid filter | only paid detail rows |
| pending filter | only pending detail rows |
| other context | excluded |

### Card-bound Exchange Projection

| Scenario | Expected result |
| --- | --- |
| exact projection | healthy |
| warning-only shape difference | warning |
| total/allocation/bucket failure | failing |
| one valid projection repair target | repairable per row |
| duplicate/ambiguous unsafe target | read-only with reason |
| paid prefix cannot be preserved | repair unavailable with paid-history reason |
| other card/context | excluded |

### Misplaced intent

| Scenario | Expected result |
| --- | --- |
| no misplaced source | healthy |
| owned source with inconsistent loan intent | failing and repairable |
| source owned by connected user | finding visible where allowed but repair unavailable owner-only |
| active replay payloads affected | count included in finding/preview |
| unrelated context/scenario | excluded |

### Piggy Bank

| Scenario | Expected result |
| --- | --- |
| all grouped links/projection totals valid | healthy |
| missing return | failing and read-only |
| wrong category/entity/context | failing and read-only |
| valuation or installment drift | failing and read-only |
| issue in another context | excluded |
| any Piggy Bank finding | no repair route/control |

## Detail and Pagination Test Matrix

| Scenario | Expected result |
| --- | --- |
| dashboard response | no finding markup |
| open one check | only selected provider called |
| default details page | at most 25 rows |
| `per_page=500` | capped at 100 |
| invalid page | controlled first/not-found behavior per page contract |
| equal sort values | stable record ID tiebreaker |
| next/previous link | retains check, context, connected user, and filters |
| live detail time newer than summary | both timestamps disclosed; rerun offered |
| details become empty after last run | empty live state without rewriting last summary silently |
| provider error | unavailable detail state, no raw exception |
| malicious description | rendered as text, not HTML |

## Preview Test Matrix

| Scenario | Expected result |
| --- | --- |
| supported finding | before/after preview and signed token |
| preview request | no financial mutation |
| preview request | no AuditOperation/AuditVersion |
| repeated unchanged preview | same deterministic digest |
| relevant data changes | digest changes or preview becomes unavailable |
| foreign-context finding ID | `404` |
| ambiguous candidate | apply unavailable with reason |
| paid-history risk | explicit implication and confirmation requirement or denial |
| unsupported issue | diagnostic-only explanation |
| Piggy Bank preview path | `404` |
| token payload | contains bounded identifiers/digest, no full financial row |
| expired/tampered token | apply rejected |

## Apply and Audit Test Matrix

| Scenario | Expected result |
| --- | --- |
| missing explicit confirmation | rejected without mutation |
| valid unchanged preview | repair committed atomically |
| state diverged after preview | conflict, no mutation |
| one required mutation fails validation | all finding changes rolled back |
| canonical reference repair | existing runner performs the change |
| Exchange Return correction | selected percentage/value option applied |
| card projection repair | extracted service preserves current transaction behavior |
| misplaced intent conversion | source and active replay payloads updated together |
| successful repair | one `admin_repair` operation |
| generated projection updates | same operation with refined mutation source |
| repair result | links to operation page |
| successful repair commit | affected check enqueued |
| rerun still finds failures | check remains failing |
| rerun finds no findings | check becomes healthy |
| failed/rejected repair | no success-only notification |

## Naming Convention Test Matrix

| Scenario | Expected result |
| --- | --- |
| non-admin naming preview/apply | `404` |
| admin preview | dry-run results, no mutation/version |
| admin apply without confirmation | rejected |
| admin apply with unchanged preview | updates through existing linter |
| naming apply changes audited records | linked `admin_repair` operation |
| naming suggestions exist | Health Check totals unchanged |
| no naming changes needed | clear maintenance result |
| selected context | only context-owned cash transactions analyzed |

## Turbo and Frontend Test Matrix

| Scenario | Expected result |
| --- | --- |
| Run one clicked | card changes to running without full-page replacement |
| one job completes | matching card and overview counters update |
| other scope broadcast | current page unchanged |
| repair preview opens | current check/detail scope retained |
| repair applies | result, summary, detail, and notification targets do not overlap |
| post-apply rerun | card shows running until completion |
| page reconnects while job running | persisted state renders correctly |
| repeated detail navigation | no duplicate lazy loads/controllers |
| renamed lazy-tabs controller | balances and maintenance tabs still work |
| browser back/forward | canonical URL and selected scope restored |
| dark mode | every state and severity has readable contrast |
| narrow mobile | cards/actions/pagination stack without horizontal overlap |
| keyboard navigation | run, detail, preview, confirm, and pagination controls reachable |

## Performance and Isolation Matrix

| Scenario | Expected result |
| --- | --- |
| initial dashboard with many findings | bounded latest-result queries only |
| Run all | five independent bounded jobs, no detail rendering |
| many detail rows | bounded page response |
| allocation-heavy check | eager loading/query count does not grow per row |
| connected-user scope | no query/data from unrelated pair |
| context switch | no reused result row or stream from prior context |
| locale switch | translated display changes without changing stable result keys |
| concurrent reruns | generation token prevents last-finish-wins corruption |

## Manual Verification Matrix

| Scenario | Expected result |
| --- | --- |
| first admin visit | clear never-run state and Run all call to action |
| Run all with worker active | cards progress independently |
| worker unavailable/error | checks show unavailable with useful safe message |
| healthy workspace | calm overview without hiding scope/time |
| failing workspace | affected counts and detail links immediately visible |
| diagnostic-only finding | reason explains absence of repair |
| repair preview | records, values, references, and paid history understandable |
| successful repair | audit link works and rerun result appears |
| partial/mixed runner result | never presented as fully successful/healthy |
| Portuguese locale | complete Health Check and maintenance translations |
| English locale | complete Health Check and maintenance translations |
| desktop light/dark | stable layout and contrast |
| mobile light/dark | readable cards, detail rows, preview, and confirmation |

## Remaining Product Decisions

There are no blocking V1 product decisions. Later work may decide:

- whether to retain a bounded diagnostic-run history
- whether a proven-safe check receives bulk repair
- whether backup belongs in Maintenance
- whether a safe generic recalculation preview/action is introduced
- when the temporary `/settings` redirect is removed
- which reference/invoice or balance-projection check enters the registry next
