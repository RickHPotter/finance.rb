# KAKASHI-20 Implementation Slices

## Delivery Rule

Each slice is independently reviewable, keeps behavior coverage intact, runs
`bin/rubocop -A`, and ends with a proposed commit description. Development stops after
each slice for review.

Measurements precede broad optimization. When a slice changes both a spec fixture and
application code, its evidence must attribute the improvement to each change separately.

## Slice 1 — Establish Repeatable Profiling

**Goal:** turn the supplied one-off profile into a reproducible baseline.

### Deliverables

- Add a documented profiling command with a fixed seed and configurable top-N output.
- Add a lightweight formatter or subscriber that can emit machine-readable example
  duration, status, file, and line data.
- Record suite-start, first-example, last-example, and finalization boundaries.
- Add opt-in SQL and FactoryBot counters for profiled examples, filtering framework
  noise consistently.
- Store artifacts outside ordinary source diffs and document how to compare samples.
- Verify profiling instrumentation does not materially distort a focused control run.

### Acceptance

- Two runs with the same seed produce comparable JSON/structured artifacts.
- Failed examples and interrupted runs retain the last known running example.
- Normal focused RSpec output remains concise.
- CI can enable the artifact path without requiring a developer-only gem.

### Suggested commit

`test: add repeatable RSpec performance profiling`

## Slice 2 — Remove Pathological Sequence-Chasing Setup

**Goal:** preserve the context-purge collision regression without runtime depending on
independent sequence drift.

### Deliverables

- Replace both ID-alignment loops in `context_purge_service_spec.rb` with deterministic,
  bounded construction of equal numeric IDs.
- Construct only the rows and callbacks needed by the behavior under test.
- Keep both directions covered: derived cash versus main card, and derived card versus
  main cash.
- Assert polymorphic type and numeric collision explicitly before calling the service.
- Add a bounded factory/SQL count around setup if the profiler supports it.
- Run the complete context-purge spec repeatedly and confirm sequence state no longer
  affects duration.

### Acceptance

- A large pre-existing difference between transaction sequences does not increase
  factory count or runtime.
- The spec still fails if purge deletion ignores `transactable_type`.
- Main-context allocations remain unchanged and derived-context rows are removed.
- No production behavior changes in this slice unless profiling independently exposes a
  purge-path regression.

### Suggested commit

`spec: bound context purge collision setup`

## Slice 3 — Make Factory Graphs Explicit and Deterministic

**Goal:** reduce hidden setup work and order sensitivity in the highest-volume factories.

### Deliverables

- Inventory factory usage and callback/association cost for User, Context,
  CashTransaction, CardTransaction, installments, allocations, exchanges, and messages.
- Replace arbitrary `.sample` reuse in factory helpers with deterministic resolution.
- Keep minimal deterministic defaults; move optional heavy graphs behind named traits.
- Remove random financial branch selection from defaults and identify explicit fuzz
  coverage separately.
- Change `create` to `build`/`build_stubbed` only where persistence is demonstrably
  irrelevant.
- Migrate call sites incrementally so every behavior remains explicit.

### Acceptance

- Identical fixed-seed focused runs create the same graph and take the same validation
  branches.
- Factory count decreases in selected high-cost request/service groups.
- No factory consumer silently loses an installment, allocation, projection, or callback
  it intended to test.
- Full affected model/request/service suites stay green.

### Suggested commit

`test: make financial factories explicit and deterministic`

## Slice 4 — Diagnose Hangs and Isolate Integrations

**Goal:** make genuine stalls actionable without masking them with broad timeouts.

### Deliverables

- Add an opt-in no-progress watchdog with a generous configurable threshold.
- Print the active example, elapsed time, Ruby thread backtraces, and PostgreSQL
  activity/lock diagnostics before termination.
- Block unintended outbound network access while preserving explicit local Capybara
  traffic and approved fakes.
- Document deterministic job, mail, push, broadcast, and assistant behavior by spec
  type.
- Ensure interrupted feature runs quit browser/driver child processes.
- Replace unbounded waits/retries with condition-based bounded helpers and useful errors.

### Acceptance

- A deliberately blocked diagnostic spec produces the expected actionable report.
- The watchdog remains disabled or nonintrusive during ordinary focused runs.
- External access fails immediately with its caller identified.
- Concurrency specs retain real database locking and do not become timing-only tests.

### Suggested commit

`test: diagnose stalled specs and isolate integrations`

## Slice 5 — Optimize Measured Application Hot Paths

**Goal:** improve production paths that remain expensive after fixture cleanup.

### Deliverables

- Re-profile services, requests, and features after Slices 2–4.
- Select hot paths by cumulative cost and production relevance, not one isolated time.
- Attribute SQL, callbacks, audit versions, recalculations, projections, messages, and
  rendering work per operation.
- Fix bounded N+1s, repeated materialization, callback storms, or duplicate derived
  recalculation behind existing financial invariants.
- Add query-count or operation-count regression coverage for each optimized path.
- Keep each unrelated hot path in its own reviewable commit when practical.

### Acceptance

- Every application optimization has before/after measurements and a non-timing
  regression assertion.
- Atomicity, audit completeness, balances, projections, and message behavior remain
  unchanged unless separately approved.
- Failure-injection and rollback specs continue to prove all-or-nothing behavior.

### Suggested commit

`perf: reduce measured financial operation work`

## Slice 6 — Separate Fast Feedback from Expensive Coverage

**Goal:** report common correctness failures earlier while keeping one authoritative
complete suite.

### Deliverables

- Define named commands/tags for fast non-browser correctness, feature/browser,
  concurrency/operational, full suite, and fixed-seed reproduction.
- Keep a simple single-process full-suite command.
- Make focused local `bin/rspec` skip SimpleCov by default, provide an explicit local
  coverage command, and force authoritative coverage in CI.
- Make missing environment, database, schema, Chrome/ChromeDriver, and service
  prerequisites fail clearly.
- Update `bin/ci` to expose phase durations and preserve the RSpec timing artifact.
- Avoid loading browser-only support for spec types that cannot use it where this can be
  done without global constant drift.

### Acceptance

- Developers can choose the documented workflow without memorizing tags or paths.
- CI retains complete RSpec and coverage authority.
- A fast failure is visible before browser and security phases start.
- Focused non-feature runs do not initialize a browser or resolve a driver.

### Suggested commit

`ci: separate fast and operational spec feedback`

## Slice 7 — Rebaseline, Budget, and Close

**Goal:** prove improvements are repeatable and establish sustainable guardrails.

### Deliverables

- Run at least three fixed-seed full-suite samples under comparable local conditions.
- Record total and phase medians, spread, top examples/groups, SQL/factory counts, and
  known irreducible costs.
- Establish warning budgets from measured variance; do not use brittle per-example
  elapsed assertions.
- Compare the post-change profile with the 2026-09-14 activation baseline.
- Run alternate seeds to expose order dependence.
- Produce manual/operational verification and a closure report.
- Evaluate parallel workers or duration-balanced sharding only as a documented next
  step if serial waste has been addressed and worker isolation is proven.

### Acceptance

- Full behavior and coverage remain green.
- No example runtime depends on transaction sequence drift or prior suite history.
- Regressions are visible through artifacts and operation/query budgets.
- The closure report distinguishes eliminated waste, optimized application work, and
  intentionally retained expensive safety coverage.

### Suggested commit

`docs: close RSpec performance audit`
