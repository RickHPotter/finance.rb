# KAKASHI-20 Decisions and Test Matrix

## Locked Decisions

### D1: Coverage quality is not traded for runtime

Financial, concurrency, audit, rollback, projection, and actionable-message assertions
remain unless an exact duplicate is proven. Expensive safety coverage may be isolated
from the fastest workflow, but remains part of authoritative CI.

### D2: Measurement precedes application optimization

The supplied profile identifies candidates. Production code changes require evidence
that application execution—not boot, setup, or teardown—is the material cost.

### D3: The 338-second example is a fixture defect first

Its polymorphic-ID collision contract is valid; its sequence-chasing construction is
not. The collision will be built deterministically and the assertions retained.

### D4: Counts protect performance better than wall-clock specs

Query, factory, callback, audit-version, projection-sync, and recalculation counts may
be asserted where stable. Ordinary specs do not fail because a machine exceeded an
arbitrary number of milliseconds.

### D5: Deterministic defaults, explicit fuzzing

Default factories use stable financial values and graph shapes. Random/fuzz behavior is
explicit, seeded, and reproducible rather than embedded in ordinary setup.

### D6: No automatic flaky-spec retries

A flake is recorded with its seed and diagnosed. Automatic retries must not convert a
non-deterministic suite into a misleading green build.

### D7: The watchdog reports before it terminates

The no-progress guard uses a generous configurable threshold and captures diagnostic
state. It does not replace bounded waits inside browser or concurrency examples.

### D8: PostgreSQL concurrency remains real

Advisory-lock, row-lock, race, and rollback concurrency specs continue using separate
database connections/transactions. Their unavoidable cost is measured and classified,
not mocked away.

### D9: Full serial reproduction remains available

Fast groupings and eventual sharding do not replace a straightforward single-process
command capable of reproducing seeds, order dependence, and shared database behavior.

### D10: Actionable-message rules are invariant

KAKASHI-20 may remove duplicate setup or avoid redundant callbacks only when the same
send, receive, auto-apply, supersession, pending, and revert contracts remain covered.
Any policy change requires separate explicit approval.

### D11: Parallelism is deferred

Parallel workers are considered only after deterministic factories, integration
isolation, database safety, browser ports, file outputs, and process cleanup are proven.

### D12: SimpleCov is explicit locally and mandatory in CI

Raw focused local `bin/rspec` runs skip SimpleCov by default, while `bin/ci` explicitly
enables authoritative coverage. A separate local coverage command remains available.

Reason: SimpleCov currently starts unconditionally in `rails_helper`, even for a single
example. Separating it can improve iteration and makes finalization cost measurable,
without weakening CI coverage.

## Profiling Matrix

| Scenario | Expected evidence |
| --- | --- |
| Focused service example | duration, file/line, factories, SQL; no browser startup |
| Focused feature example | browser startup separated from example execution |
| Full fixed-seed suite | structured artifact plus human top-N summary |
| Repeated same-seed run | comparable ordering and graph inputs |
| Alternate seed | failures reproduce with printed seed |
| Interrupted run | active example remains identifiable |
| Finalization | coverage/cleanup time separated from example time |
| Profiler disabled | ordinary RSpec behavior and concise output unchanged |

## Context Purge Regression Matrix

| Collision shape | Required result |
| --- | --- |
| Main Card ID equals derived Cash ID | derived allocations removed; main Card allocations retained |
| Main Cash ID equals derived Card ID | derived allocations removed; main Cash allocations retained |
| Sequences differ by hundreds | bounded setup; no chase loop |
| Purge ignores polymorphic type | regression example fails |
| Main row references derived row | purge rejects without partial deletion |
| Post-delete invariant fails | complete purge transaction rolls back |
| Callback-bypassed financial rows | destruction evidence remains complete |

## Factory Audit Matrix

| Factory behavior | Expected contract |
| --- | --- |
| User/Context default | minimal deterministic owner and main context |
| CashTransaction default | explicit required installment graph only |
| CardTransaction default | optional allocations/projections moved behind clear traits where safe |
| Existing association reuse | deterministic selection or explicit caller input |
| Polymorphic helper | explicit type unless the example is seeded fuzz coverage |
| Dates/month/year | named values that select a known billing branch |
| Price/sign | named integer cents with a known direction |
| Random trait | reproducible seed and printed failing input |
| Persistence irrelevant | `build`/`build_stubbed`, with no lost database invariant |

## Hang Classification Matrix

| Simulated stall | Required diagnostic |
| --- | --- |
| PostgreSQL row/advisory lock | active example, sessions, wait event, blocker identity |
| Ruby callback recursion | active example and thread backtrace |
| Capybara wait | selector/action and bounded failure |
| Job/mail/push/broadcast | adapter mode and queued/executing work |
| External HTTP attempt | immediate rejection with caller |
| Child process leak | process identity and cleanup result |
| Intentional concurrency wait | bounded synchronization, not watchdog false positive |

## Application Optimization Matrix

| Surface | Preferred regression evidence |
| --- | --- |
| Cash/card indexes and month frames | bounded SQL and stable result count/total |
| Dashboards/drill-downs | bounded SQL and reconciled totals |
| Context clone/purge | bounded writes/recalculations and exact graph snapshot |
| Balance/counter recalculation | one intentional pass per operation |
| Subscriptions | bounded synchronization count and unchanged history |
| Exchange projections | exact affected buckets and sync count |
| Messages | exact created/applied/superseded set and no policy drift |
| Audit/rollback | complete version set, bounded planning queries, atomic failure |
| Bulk mutation | no callback storm and complete audit evidence |

## Workflow Matrix

| Workflow | Purpose | Required characteristics |
| --- | --- | --- |
| Focused | current example/file | fastest useful feedback, reproducible command |
| Fast correctness | models/concerns/services/requests without expensive tags | no browser, failures early |
| Feature | Hotwire/browser behavior | explicit Chrome prerequisite and cleanup |
| Operational | concurrency, rollback, large graphs | real PostgreSQL, bounded waits |
| Full serial | authoritative RSpec reproduction | all examples, fixed/printed seed |
| Profile | diagnosis | structured timing/count artifact |
| CI | merge confidence | full coverage, style, JS, audits, phase timings |

## Closure Evidence

KAKASHI-20 is complete only when:

1. the pathological context-purge setup is bounded while its regression remains live;
2. repeatable profiles distinguish setup from application work;
3. the highest-cost factories and application paths have measured explanations;
4. stalls identify the current example and useful diagnostic state;
5. focused, feature, operational, full, profiling, and CI commands are documented;
6. three comparable full runs support realistic budgets;
7. full specs and authoritative coverage remain green; and
8. the closure report records intentionally retained expensive safety coverage rather
   than presenting it as unfinished optimization.
