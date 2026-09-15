# KAKASHI-20 Performance and Spec Quality Contract

## Objective

Make the RSpec suite fast, deterministic, and diagnosable enough for everyday use,
then use measured slow examples to improve genuine application hot paths without
weakening financial regression coverage.

KAKASHI-20 is not a test-deletion exercise. A faster green suite is valuable only when
it continues to protect transaction history, projections, messages, audits, context
isolation, concurrency, and rollback behavior.

## Scope

The feature covers four separately measured costs:

1. Ruby/Rails boot, schema maintenance, and global suite setup;
2. example setup, including factories, callbacks, and database writes;
3. the application behavior inside the example;
4. cleanup, browser shutdown, coverage collation, and other finalization.

An optimization must identify which cost it changes. Total example duration alone is a
useful alarm, but it is not enough to justify changing application code.

## Measurement Contract

The checked-in profiling path must report, where technically reliable:

- total wall time and time before the first example;
- example description, file, line, status, and elapsed time;
- setup and exercise time as separate values when a spec exposes that boundary;
- SQL statement count, excluding schema/cache noise consistently;
- FactoryBot factory count;
- browser, job, mail, broadcast, and explicit wait activity;
- the running example when progress stops; and
- machine-readable results that can be compared between runs.

Measurements use a monotonic clock. Timing budgets are established only after repeated
fixed-seed samples demonstrate a stable baseline. Query and operation counts are the
preferred regression assertions; machine-specific wall-clock assertions do not belong
in ordinary specs.

## Spec Quality Contract

Every expensive example must retain one clear behavioral responsibility. The audit may:

- replace persistence with `build` or `build_stubbed` when the behavior never reaches
  the database;
- replace implicit factory graphs with explicit traits or focused records;
- split a broad example when setup and assertions protect independent contracts;
- consolidate exact duplicates when the surviving example preserves the same boundary;
- move behavior to a lower test layer when the higher layer adds no integration value;
- replace random financial inputs with named deterministic values; and
- construct an otherwise-impossible legacy database shape directly when callbacks are
  not the subject under test.

The audit may not:

- remove a financial invariant merely because it is expensive;
- mock the domain service whose behavior the example exists to protect;
- replace PostgreSQL concurrency coverage with an in-memory approximation;
- hide flaky behavior behind automatic retries or longer browser waits; or
- make factories globally unrealistic to optimize one example.

## Factory Contract

Factories are minimal, deterministic defaults. Expensive association graphs, generated
installments, projections, notifications, and friend-side synchronization should be
explicit traits when callers do not universally need them.

Fields that affect signs, billing buckets, ordering, paid-history guards, or validation
branches must not use `rand`, `.sample`, or Faker by default. Random data may remain in
an explicitly requested fuzz/random trait, but reproducibility must be tied to the RSpec
seed and failures must print enough input to reproduce them.

Helpers such as `custom_create` must not select an arbitrary existing association with
`.sample`. Reuse must be deterministic and must not silently couple examples to whichever
record happened to be created first.

## Hang and Flakiness Contract

A no-progress watchdog reports diagnostics before stopping a genuine hang. Its report
must include the running example, elapsed time, process/thread state, and useful
PostgreSQL activity or lock information. It is diagnostic protection, not a blanket
per-example timeout.

The suite must classify a stall before changing limits:

- database/advisory lock;
- callback or projection recursion;
- job, mail, push, broadcast, or assistant integration;
- browser/driver wait;
- retry/poll loop;
- child process or execution-session leak; or
- external network access.

Tests use explicit adapters for integrations and fail on unintended outbound network
access. Concurrency specs keep real PostgreSQL transactions and bounded synchronization.

## Application Performance Contract

Application code is optimized only after profiling shows that the exercised production
path—not pathological fixture creation—is the cost. Priority surfaces are:

- cash/card indexes and month-year endpoints;
- dashboards and drill-down reports;
- context clone and purge;
- balance and counter recalculation;
- subscription synchronization;
- exchange and return-projection synchronization;
- actionable-message processing without changing its policy;
- audits, rollback, health checks, and bulk mutations.

Accepted improvements include bounded eager loading, avoiding duplicate relation
materialization, batching audited work safely, and performing derived recalculation once
per completed operation. Transaction atomicity and immediately visible financial
consistency remain explicit invariants.

## Suite Architecture Contract

Fast feedback and authoritative verification are separate named workflows:

- focused/changed specs for development;
- a fast non-browser correctness suite;
- feature/browser coverage;
- expensive operational and PostgreSQL concurrency coverage;
- the complete single-process suite used to reproduce shared-state and ordering issues;
- full CI, including style and security checks.

Parallel execution or duration-balanced sharding is a later optimization. It may land
only after database isolation, ports, files, external adapters, and process cleanup are
proven worker-safe.

## Coverage Contract

CI remains the authoritative coverage run and must not lose the existing threshold or
report. Raw focused local `bin/rspec` invocations skip SimpleCov by default so coverage
startup and finalization do not tax the ordinary feedback loop. A separate explicit
local coverage command remains available, and `bin/ci` always enables coverage.

## Explicitly Out of Scope

- replacing RSpec or FactoryBot without evidence that either is the bottleneck;
- reducing coverage targets to improve time;
- changing production financial or actionable-message semantics for a test shortcut;
- blanket internal mocking;
- arbitrary elapsed-time assertions;
- parallelization before correctness and isolation work;
- treating one unusually fast run as proof of a durable performance improvement.
