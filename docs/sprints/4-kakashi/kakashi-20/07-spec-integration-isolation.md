# KAKASHI-20 Spec Integration Isolation

## Outbound Network

RSpec blocks unstubbed external HTTP through WebMock. Loopback traffic remains enabled
for Capybara, Selenium, and the in-process Rails test server. A spec that intentionally
models an HTTP integration must declare a WebMock stub; an accidental request fails
immediately and reports the attempted method, URL, and caller.

## Integration Behavior

| Integration | Test behavior |
| --- | --- |
| Active Job | Rails' test adapter records enqueued jobs. Specs run jobs only through explicit Active Job test helpers or direct job calls. |
| Action Mailer | The test delivery method stores messages in `ActionMailer::Base.deliveries`; no SMTP connection is opened. |
| Web Push | Specs with push subscriptions stub `WebPush.payload_send`. An unstubbed HTTP attempt is rejected by the network guard. |
| Turbo / Action Cable broadcasts | The test cable adapter keeps broadcasts inside the process and exposes them to broadcast matchers. |
| Assistant conversations | “Assistant” is an application conversation/message classification; its specs execute local policy and financial workflows and do not invoke an external model. |
| Capybara / Selenium | Only loopback connections are allowed. Every suite shutdown and Ruby process exit attempts to quit created drivers and reset sessions. |
| PostgreSQL concurrency | Concurrency specs retain real connections, transactions, row locks, and advisory locks. Queue and thread synchronization is bounded with descriptive five-second failures. |

## No-progress Watchdog

The watchdog is deliberately opt-in and does not wrap examples in a timeout. Enable it
for either ordinary RSpec or the profiling command:

```text
RSPEC_STALL_TIMEOUT_SECONDS=120 bin/rspec-profile spec/services
RSPEC_STALL_TIMEOUT_SECONDS=120 bin/rspec spec/features
```

If one example makes no progress beyond the configured threshold, the watchdog prints:

- the exact rerun argument and full example description;
- elapsed monotonic time;
- every Ruby thread status and backtrace;
- current-database PostgreSQL activity, wait events, blocking PIDs, queries, and locks.

It then attempts browser cleanup and terminates the process, leaving the profiler's
`.active.json` breadcrumb intact. Invalid, absent, or non-positive values keep the
watchdog disabled.

This is diagnostic protection for genuine stalls. Ordinary synchronization assertions
use bounded condition waits, while financial concurrency behavior continues to be
proved by PostgreSQL rather than mocked or replaced by elapsed-time sleeps.
