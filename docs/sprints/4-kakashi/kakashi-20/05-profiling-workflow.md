# KAKASHI-20 Profiling Workflow

## Run a Profile

`bin/rspec-profile` loads `.env.test` when present and otherwise loads `.env`. With no
arguments it runs the complete suite using the stable activation seed:

```text
bin/rspec-profile
```

Pass any ordinary RSpec path, line, tag, or formatter-compatible argument for a focused
profile:

```text
bin/rspec-profile spec/services/logic/context_purge_service_spec.rb
bin/rspec-profile spec/requests/cash_transactions_spec.rb:1962
```

The command retains RSpec's human-readable slow-example report and writes the structured
artifact to `tmp/rspec-profile.json`. Files under `tmp/` are ignored by Git.

## Configuration

The command accepts three task-specific environment variables:

| Variable | Default | Purpose |
| --- | --- | --- |
| `RSPEC_PROFILE_PATH` | `tmp/rspec-profile.json` | structured artifact destination |
| `RSPEC_PROFILE_SEED` | `20260914` | seed used when `--seed` is absent |
| `RSPEC_PROFILE_TOP` | `10` | number passed to RSpec's `--profile` |

An explicit `--seed` or `--profile` argument wins over its environment default.

## Artifact Contents

The JSON artifact has a schema version and unique run identifier. It records:

- process start, finish, exit status, signal, command, and total duration;
- pre-formatter bootstrap and post-RSpec process time;
- formatter start, first-example start, last-example finish, and RSpec finish;
- RSpec load time, example time, counts, failures, and pending examples;
- each example's stable ID, description, file, line, rerun argument, status, duration,
  uncached SQL count, cached SQL count, FactoryBot count, and factory-name breakdown;
- exception class and message for a failed example.

`post_rspec_seconds` includes work after RSpec emits its summary, including SimpleCov
result processing in the current configuration. Slice 6 will make local coverage
explicit and CI coverage mandatory, allowing that difference to be measured directly.

Schema and transaction-control notifications are excluded from `sql_count`. Cached SQL
is reported separately. Counts cover the complete example lifecycle, including hooks,
because RSpec does not expose a universal setup-versus-exercise boundary.

## Stalled or Interrupted Runs

While an example is running, the formatter writes an adjacent active artifact:

```text
tmp/rspec-profile.active.json
```

It contains the process ID, run identifier, suite start, and exact active example with
its rerun argument. A normally completed run removes this file. If the process is killed
or genuinely stalls, it remains as the first diagnostic breadcrumb. Slice 4 will build
the no-progress watchdog and thread/PostgreSQL diagnostics on this contract.

## Comparing Runs

Use the same spec selection and seed. Compare stable example IDs, ordering, SQL counts,
factory counts, and factory breakdown before comparing elapsed time. Small timing
differences are expected from machine load; a changed query/factory count is usually
stronger evidence.

Do not establish a performance budget from a single run. Kakashi-20 closure requires at
least three comparable full-suite samples after the pathological fixture and measured
factory costs have been corrected.
