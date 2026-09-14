# KAKASHI-21 Closure Report

## Status

Implementation and automated verification are complete as of 2026-09-14. Production-
shaped manual acceptance remains explicit in
[05-manual-verification.md](05-manual-verification.md); its sign-off must not be inferred
from automated coverage.

## Delivered Contract

- The reference-merge form requires an explicit, localized choice between preserving
  the existing combine behavior and reallocating persisted unpaid billing content.
- Combine moves source content into either adjacent target while leaving later buckets
  unchanged.
- Reallocation is forward-only and moves every affected persisted installment and
  monetary card-bound exchange exactly one calendar month.
- Installment identity, parent, number/count, price, starting price, allocations, paid
  state, and original date remain unchanged; only billing month/year and invoice routing
  move.
- Existing canonical references/invoices are reused, missing tail rows are created, and
  final invoices are reconstructed from membership.
- Empty exchange-only invoices are removed, exchange-return projections reconcile, and
  paid/ambiguous graphs fail before mutation.
- Both modes share one card/Context advisory boundary, deterministic graph locking,
  stale-plan protection, one structured result contract, and one grouped audit
  operation.
- Guarded rollback restores exact graph identity and content, rejects any later
  divergence, remains atomic after failure, and is idempotent for repeated tokens.
- Reference merging does not change actionable-message send, receive, auto-apply,
  supersession, pending, or revert policy.

## UI and Navigation Closure

- English and Brazilian Portuguese labels now describe the concrete financial
  consequence of each mode before submission.
- Rejected source/target months and the selected mode remain rendered with their error.
- Stimulus preserves a server-rendered invalid selection on connect, while a subsequent
  month edit clears and disables an unavailable forward-reallocation choice.
- The merge form stacks at compact widths and carries explicit dark-mode surfaces,
  labels, controls, focus treatment, and full-width mobile actions.
- HTML and Turbo failures remain on a navigable `422` form; success uses `303` and
  preserves the sanitized user-card destination.
- The supporting navigation regression now exercises the structured `merge_result`
  boundary instead of the removed Boolean mock.

## Automated Evidence

Focused closure verification on 2026-09-14:

- complete KAKASHI-21 service, planner/apply, audit rollback, concurrency, request, and
  supporting-navigation selection: 72 examples, 0 failures;
- reference UI/navigation request selection: 22 examples, 0 failures;
- reference-merge JavaScript behavior: passing; and
- all JavaScript test files: 7 files passing before the full CI gate.

Final `bin/ci` verification on 2026-09-14:

- Ruby style: 1,007 files, no offenses;
- ERB lint: 105 files, no errors;
- RSpec: 2,085 examples, 0 failures, 92.47% line coverage;
- JavaScript: 27 tests, 0 failures;
- Bundler Audit: no vulnerabilities; and
- Brakeman: no errors or security warnings.

The first full run exposed an order-dependent test fixture in the earlier-history
duplicate-invoice regression: creating the duplicate while the canonical invoice was
empty allowed callbacks to remove the object later used by the test. The fixture now
attaches and locks the paid historical installment first, then verifies that two earlier
invoices exist. The focused planner suite and the complete second CI run pass.

## Remaining Human Gate

Run [05-manual-verification.md](05-manual-verification.md) against production-shaped,
safely mutable data. Record the card/month/operation IDs used and complete its sign-off.
Any mismatch reopens the relevant graph case as a failing focused regression before a
production change. No schema migration or data backfill belongs to this feature.

## Manual-Acceptance Finding: Paid Combine Projection

Manual verification on 2026-09-14 exercised user card `#3`, October → November 2026,
in combine mode. Exchange `#4651` belongs to projection `#10009`, whose installment
`#45360` is already paid. The original path discovered the protected history only while
saving the Exchange, rolled the transaction back, and returned the generic
`apply_failed` message.

Combine now locks the source projections and the destination projections for matching
source Entities before its first mutation. Paid history first returns a precise request
for historical confirmation. Once confirmed, a supported graph retains every paid
installment's ID, date, amount, and settlement state, consolidates the source and target
under the canonical target projection, and rebuilds only the unpaid remainder.

The production-shaped card `#3` graph was exercised inside an outer rollback-only
transaction. Its October and November projections combined to `427830`, retained paid
installments `#45360` (`62241`) and `#45361` (`38203`), and produced one pending
installment of `327386`. Audit preview was applyable and confirmed rollback restored the
source reference, source projection, exchange ownership, and paid rows. Focused coverage
also proves that a later exchange appends a new pending installment to the canonical
projection without rewriting completed payments. Unsupported or inconsistent projection
graphs continue to reject before mutation.

The same confirmed-history contract now covers reallocation. Because buckets move
latest-to-earliest, a paid projection can retain its CashTransaction and paid installment
facts while its exchanges and unpaid schedule advance one month. The production-shaped
card `#3` plan (10 buckets, 147 card installments, and 120 exchanges) was eligible and
applied successfully inside an outer rollback-only transaction; the outer rollback
restored the exact sampled graph and audit-operation count. Regression coverage repeats
the post-reallocation consumption case and verifies that only the new amount becomes
pending.
