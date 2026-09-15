# KAKASHI-20 Closure Report

## Outcome

KAKASHI-20 is complete as of 2026-09-15. The full serial suite passes 2,111 examples
under the fixed reproduction seed and two alternate seeds. The activation run's
338.07-second sequence-chasing fixture has been replaced by a bounded construction,
measured application work has non-timing regression coverage, stalls are diagnosable,
and local/CI workflows now separate fast feedback from authoritative coverage.

No financial assertion, actionable-message policy, concurrency boundary, rollback
contract, or coverage requirement was weakened to obtain the improvement.

## Measurement Protocol

The final comparison used:

- one process, with the complete suite in serial order;
- seed `20260914` for three comparable samples;
- SimpleCov disabled so coverage finalization did not distort runtime;
- the KAKASHI profiler with SQL and FactoryBot counters enabled;
- a 180-second no-progress watchdog; and
- the same working tree and local PostgreSQL/browser environment for every sample.

The retained machine-readable artifacts are local runtime artifacts under `tmp/` and
are intentionally not source-controlled. Reproduce a sample with:

```bash
bin/specs reproduce --profile-top 25 --watchdog 180
```

Run authoritative coverage separately with `bin/specs coverage`, or through `bin/ci`.

## Fixed-Seed Samples

| Sample | Examples | Failures | Example time | Process time | Load time | Post-RSpec | Uncached SQL | Factories |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 2,111 | 0 | 381.16s | 386.72s | 5.02s | 0.16s | 391,885 | 12,528 |
| 2 | 2,111 | 0 | 369.82s | 372.71s | 2.01s | 0.69s | 391,966 | 12,528 |
| 3 | 2,111 | 0 | 353.40s | 355.74s | 2.01s | 0.13s | 391,909 | 12,528 |
| **Median** | **2,111** | **0** | **369.82s** | **372.71s** | **2.01s** | **0.16s** | **391,909** | **12,528** |

Process time ranged from 355.74 to 386.72 seconds: 30.98 seconds, or 8.31% of
the median. SQL ranged by 81 statements (approximately 0.02%), while the factory count
was identical. This supports warning bands, but not portable elapsed-time assertions.

### Phase-attributed example time

These figures sum example bodies classified by source file. They intentionally exclude
RSpec lifecycle and transition overhead, so they do not add up to process time.

| Phase | Median | Minimum | Maximum | Range |
| --- | ---: | ---: | ---: | ---: |
| Fast correctness | 193.39s | 192.99s | 207.26s | 14.27s |
| Feature/browser | 38.01s | 33.00s | 38.74s | 5.74s |
| Operational | 49.64s | 48.74s | 51.91s | 3.16s |

The authoritative coverage partition from Slice 6 also reconciles exactly: 1,949 fast,
34 feature, and 128 operational examples total 2,111, with 26,477 of 28,615 lines
covered (92.52%).

## Activation Comparison

The 2026-09-14 activation profile ran 2,094 examples in approximately 758 seconds of
example time, with 92.51% line coverage. Its largest example spent 338.07 seconds
chasing independent database sequences to manufacture an ID collision.

The final median is 369.82 seconds of example time for 2,111 examples, a 51.21%
reduction while adding 17 examples and increasing measured coverage to 92.52%. The
same collision regression now takes approximately 0.41–0.45 seconds and continues to
prove that polymorphic type participates in deletion identity.

## Remaining Cost Centres

The slowest median examples are useful safety or browser coverage rather than the
eliminated unbounded fixture:

| Example | Median | Why retained |
| --- | ---: | --- |
| Monthly Analysis source navigation | 4.42s | Real browser navigation and restored URL state |
| Same-card reference reallocation race | 3.50s | Real PostgreSQL serialization |
| Independent reference merge race | 2.87s | Real locking and stale-plan rejection |
| Health-check repair race | 2.67s | Exactly-once repair under contention |
| Allocation mutation race | 2.67s | Atomic mutation under contention |
| Entity merge race | 2.66s | Exact preview and graph serialization |
| Reference merge stale racer | 2.63s | No partial merge after conflict |
| Concurrent rollback | 2.58s | Duplicate rollback serialization |

The largest cumulative files remain the broad financial contracts:

| Group | Median cumulative time | Examples |
| --- | ---: | ---: |
| Card transaction requests | 23.88s | 70 |
| Cash transaction requests | 18.18s | 104 |
| Cash installment requests | 12.11s | 41 |
| Reference reallocation concurrency | 10.12s | 3 |
| Reference reallocation application | 8.32s | 16 |
| Reference rollback adapter | 6.29s | 9 |
| Conversation requests | 5.76s | 48 |

These groups cover dense financial graphs, projection synchronization, audit rollback,
and genuine concurrent database behavior. They remain candidates for future measured
work, not evidence of an unfinished KAKASHI-20 defect.

## Warning Budgets

Budgets are diagnostic warnings for comparable profiling runs. They are not RSpec
failures and must not be converted into per-example wall-clock assertions.

| Signal | Warn above | Basis |
| --- | ---: | --- |
| Full process median | 420s | 12.7% above measured median and 8.6% above observed maximum |
| Fast example-body phase | 225s | Above the 207.26s observed maximum |
| Feature example-body phase | 50s | Allows browser startup/rendering variance |
| Operational example-body phase | 60s | Allows real lock scheduling variance |
| Uncached SQL median | 400,000 | Approximately 2% above the stable 391,909 median |
| Factory median | 12,800 | Approximately 2% above the stable 12,528 count |
| One example | 12s | Diagnostic threshold above the observed 7.95s maximum |

A warning means compare the machine-readable top examples/groups and counters against
this report. Stable query or operation regressions should become focused count-based
specs; machine speed alone is not a failure.

## Alternate Seeds and Order Dependence

Two complete serial runs used different ordering:

| Seed | Examples | Failures | Example time | Process time |
| --- | ---: | ---: | ---: | ---: |
| `20260915` | 2,111 | 0 | 348.17s | 350.49s |
| `424242` | 2,111 | 0 | 363.76s | 366.10s |

Repeated sampling exposed looped navigation specs that depended on the previously
authenticated request actor. Those specs now sign in the intended owner before every
request and identify the failing route in status assertions. This changes test
isolation only; it does not alter application navigation or authorization behavior.

## Manual and Operational Verification

The closure evidence verifies:

- focused, fast, feature, operational, full, coverage, and seed-reproduction commands;
- no browser prerequisite resolution during focused non-feature runs;
- immediate environment/database prerequisite failures;
- structured artifacts for completed, failed, and interrupted profiles;
- active-example, Ruby-thread, and PostgreSQL-lock diagnostics from the watchdog;
- blocked unintended external HTTP with loopback Capybara traffic retained;
- bounded condition-based concurrency synchronization;
- exact CI partition membership and merged authoritative coverage; and
- a simple single-process path for reproducing ordering and shared-state failures.

For future maintenance, run one fixed-seed profile after material factory, callback, or
suite-architecture changes. Run three comparable samples before resetting these
budgets. Use `bin/ci` as the final merge/deployment gate.

## Parallelism Decision

Parallel workers and duration-balanced sharding remain deferred. Serial waste has been
removed enough that parallelism could improve elapsed CI time, but isolation is not yet
proven for specs that deliberately truncate shared tables, exercise PostgreSQL locks,
start browser servers, or write coverage/profile artifacts to shared paths.

Before adoption, each worker needs its own database, server port, coverage command
name/result set, profiler artifact path, and cleanup boundary. Concurrency and rollback
specs should remain available in the serial reproduction profile even if CI later uses
measured duration-balanced shards.

## Closed Scope

KAKASHI-20 eliminated the pathological fixture, made hidden factory work deterministic,
added stall and integration diagnostics, optimized a measured production hot path,
introduced faster workflows without weakening coverage, and established evidence-based
warning budgets. Remaining expensive financial and concurrency coverage is deliberate.
