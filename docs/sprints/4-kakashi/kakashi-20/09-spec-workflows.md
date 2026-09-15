# KAKASHI-20 Spec Workflows

## Local Commands

`bin/specs` loads `.env.test`, falling back to `.env`, and accepts these named
profiles:

| Command | Purpose | Coverage |
| --- | --- | --- |
| `bin/specs focused spec/path_spec.rb:42` | Current file or example | off |
| `bin/specs fast` | Non-browser correctness without operational groups | off |
| `bin/specs feature` | Capybara/Selenium feature specs | off |
| `bin/specs operational` | Concurrency, rollback, and reference-merge safety | off |
| `bin/specs full` | Complete single-process suite at the stable seed | off |
| `bin/specs coverage` | Complete local suite with SimpleCov | on |
| `bin/specs reproduce --seed 1234` | Profiled full or focused reproduction | off unless requested |

Additional RSpec arguments are appended to every profile. Set `RSPEC_SEED` to change
the default seed used by named suite profiles, or pass an explicit `--seed` argument.
Raw `bin/rspec` remains available for ordinary focused work and no longer starts
SimpleCov unless `COVERAGE=true` is explicit.

## Suite Partition

The CI partitions are disjoint:

- `fast` excludes feature and `operational` metadata;
- `feature` selects `spec/features`;
- `operational` selects the derived `operational` tag.

Operational metadata is derived for PostgreSQL concurrency specs, audit rollback
services, and reference-merge services. These retain real database locking, complete
graph rollback, and failure-injection coverage; they are moved out of the fastest
feedback phase, not removed or weakened.

`full` deliberately remains a single RSpec process. It is the authoritative local tool
for reproducing shared-state, sequence, and ordering failures that a partitioned run
cannot expose.

## Coverage and CI

SimpleCov is opt-in locally and mandatory in both `bin/ci` and GitHub CI. The three CI
RSpec phases use unique SimpleCov command names, share results for up to one hour, and
therefore produce one combined report containing the complete suite. The fast phase
clears stale local result data before starting.

Each CI phase runs through `bin/rspec-profile` and writes a separate structured timing
artifact:

- `tmp/ci-rspec-fast.json`;
- `tmp/ci-rspec-feature.json`;
- `tmp/ci-rspec-operational.json`.

GitHub uploads those files and the combined `coverage/` report even when a phase fails.
The CI runner also displays the duration of each named phase directly.

## Prerequisite Failures

- Local named workflows require `.env.test`, `.env`, or `DATABASE_URL`.
- PostgreSQL connectivity is checked before database cleanup and reports a dedicated
  prerequisite error.
- Schema maintenance still fails before examples when migrations are pending.
- Chrome and ChromeDriver are resolved and verified before a selected feature suite;
  non-feature runs neither resolve nor start the browser.
- Browser sessions retain the suite and process-exit cleanup established in Slice 4.

## Slice Validation

Fixed seed `20260914`, with CI-equivalent profiling and coverage enabled:

| Phase | Examples | Failures | Example time |
| --- | ---: | ---: | ---: |
| Fast | 1,949 | 0 | 407.76s |
| Feature | 34 | 0 | 53.44s |
| Operational | 128 | 0 | 83.89s |
| Combined | 2,111 | 0 | 545.09s |

The generated SimpleCov result set contains the three distinct command identities and
the final merged report covers 26,477 of 28,615 lines (92.52%). A dry-run of all named
profiles independently confirmed that their counts sum exactly to the full suite.
