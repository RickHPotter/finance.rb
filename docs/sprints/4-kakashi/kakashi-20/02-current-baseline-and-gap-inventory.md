# KAKASHI-20 Current Baseline and Gap Inventory

## Baseline Provenance

The activation baseline comes from the developer's local command on 2026-09-14:

```text
bundle exec rspec --profile
2094 examples, 0 failures
files: 2.60 seconds
examples: 12 minutes 38 seconds
coverage: 26,444 / 28,582 lines (92.51%)
```

This is a useful first sample, not yet a performance budget. It does not record the
RSpec seed, hardware/load conditions, SQL counts, factory counts, setup/exercise split,
or time spent finalizing SimpleCov. Repeated fixed-seed runs are still required before
comparing smaller improvements or enabling CI regression gates.

## Headline Finding

The slowest example took 338.07 seconds:

```text
Logic::ContextPurgeService#call does not delete main-context entity/category rows when
derived cash transaction ids match card transaction ids
spec/services/logic/context_purge_service_spec.rb:18
```

It consumed about 44.6% of the complete 758-second example run. The ten slowest examples
consumed 360.36 seconds (47.6%); therefore the other nine examples in that list combined
for only about 22.29 seconds. Removing the pathological setup cost is the dominant first
opportunity and must happen before interpreting the rest of the ranking.

## Confirmed Cause of the Outlier

The example protects a valid polymorphic-association regression: a `CashTransaction`
and `CardTransaction` may have the same numeric ID, and deleting allocations by numeric
ID without respecting `transactable_type` can destroy main-context rows.

Its helper currently creates complete transactions in a loop until independent
PostgreSQL sequences happen to produce the same value:

```ruby
while main_card_transaction.id != derived_cash_transaction.id
  # create another complete transaction on whichever sequence is behind
end
```

This cost is unrelated to `ContextPurgeService#call`. It depends on accumulated sequence
drift, and PostgreSQL sequences do not roll back with transactional fixtures. At audit
time, the local test database showed:

| Table | Maximum persisted ID | Sequence value |
| --- | ---: | ---: |
| `card_transactions` | 1656 | 1696 |
| `cash_transactions` | 1943 | 2040 |

The two sequences were already hundreds of values apart. Each attempt creates a full
transaction graph and runs callbacks, so later suite runs can become progressively more
expensive even when every example remains green.

The correct first fix is to build the intended same-ID legacy shape deterministically,
without exercising hundreds of irrelevant callbacks, while retaining the exact purge
and polymorphic-allocation assertions.

## Remaining Profile Ranking

After excluding the 338-second anomaly, the current candidates are ordinary but still
worth classifying:

| Area | Observed duration | Initial classification |
| --- | ---: | --- |
| Entity merge concurrency | 3.17s | real PostgreSQL serialization candidate |
| Allocation trend feature | 2.99s | browser plus dashboard/query work |
| Reference reallocation concurrency | 2.69s / 2.32s | real locking coverage |
| Reference rollback integrity retry | 2.53s | large audited graph plus failure injection |
| Audit rollback concurrency | 2.48s | real PostgreSQL serialization candidate |
| Shared return transfer/partial pay | 2.14s | request, jobs, messages, projections |
| Reference apply integrity failure | 2.05s | large graph plus rollback |
| Cash create message regression | 1.93s | request plus notification/projection graph |

These durations do not yet prove waste. Concurrency examples may reasonably cost more
than unit examples, and browser startup must be separated from page execution before
optimizing feature coverage.

## Current Suite Shape

The repository has 271 spec files:

| Type | Files |
| --- | ---: |
| Services | 151 |
| Requests | 51 |
| Models | 32 |
| Features | 14 |
| Concerns | 14 |
| Components | 4 |
| Jobs | 2 |
| Helpers | 2 |
| Migrations | 1 |

All 271 files require `rails_helper`; none currently use only `spec_helper`. This does
not prove Rails boot is the largest cost—the reported file load was only 2.60 seconds in
the supplied run—but it means even pure Ruby examples cannot currently demonstrate a
lighter execution path.

## Global Setup Inventory

Current global behavior includes:

- SimpleCov starts unconditionally at the top of `rails_helper`;
- Rails and the full application environment load for every spec file;
- schema maintenance runs when `rails_helper` loads;
- DatabaseCleaner truncates the database once before the suite;
- transactional fixtures isolate examples;
- Faker unique state clears before every example;
- Bullet starts after Rails initialization, with known association safelists;
- the Selenium driver is registered globally, while the browser starts lazily when a
  feature example first needs it;
- Capybara waits are bounded at five seconds;
- CI currently runs the full RSpec suite as one undifferentiated step.

There is no checked-in profiler for per-example SQL/factory counts, no machine-readable
timing artifact, and no no-progress watchdog.

## Factory and Determinism Gaps

The default `CardTransaction` factory creates allocations and an installment graph.
Transaction creation can therefore exercise callbacks and derived projections even in
examples that need only a persisted parent.

The factory layer also contains behavior that can make setup depend on incidental state:

- `custom_create` uses an arbitrary associated record via `.sample`;
- `custom_create_polymorphic` chooses a model with `.sample`;
- random traits use Faker, Ruby `rand`, and `.sample` for comments, prices, dates, and
  installment shapes;
- some random values affect financial signs, months, validation, and ordering;
- implicit reuse of existing associations can couple setup to prior factory calls within
  the same example.

The audit must inventory call sites before changing these helpers. Existing specs may
deliberately request randomness, but deterministic defaults and explicit graph traits
are the target contract.

## Hang and Integration Gaps

The suite has real concurrency examples and explicit short sleeps. Some specs execute
jobs, mail, projection synchronization, and browser navigation. Current configuration
does not provide:

- a running-example/no-progress diagnostic;
- PostgreSQL lock/activity capture on a stall;
- a central outbound-network prohibition;
- a machine-readable flake/seed history;
- explicit process cleanup evidence for interrupted browser runs; or
- documented per-spec-type job/broadcast/integration modes.

Longer Capybara waits would obscure rather than solve these gaps.

## CI and Workflow Gaps

`bin/ci` currently performs setup, Ruby/ERB style, the full RSpec suite, JavaScript
tests, dependency audit, and Brakeman in sequence. It does not print a durable timing
summary or retain an RSpec timing artifact.

The repository documents focused commands, but has no named fast correctness suite,
expensive operational suite, profiling command, fixed-seed reproduction command, or
watchdog command. A failed prerequisite can still look like a silent delay rather than
an explicit database/browser/environment failure.

## Conclusions

1. The supplied profile is sufficient to begin; rerunning the entire 12-minute suite
   before fixing the sequence-alignment example would mostly reproduce known waste.
2. The first code slice should make profiling repeatable and machine-readable.
3. The first spec correction should remove sequence-chasing while preserving the exact
   polymorphic collision regression.
4. The suite must then be re-profiled. Only that post-correction ranking should drive
   broader factory or application optimization.
5. Parallel workers and hard performance budgets remain deferred until repeatability
   and isolation are demonstrated.
