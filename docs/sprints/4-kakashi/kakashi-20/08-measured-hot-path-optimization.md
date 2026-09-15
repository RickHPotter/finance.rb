# KAKASHI-20 Measured Hot-path Optimization

## Selection

The post-fixture profile identified reference reallocation and its rollback coverage as
the dominant production-relevant cluster. The successful twelve-month reallocation
example was selected as the control because it moves five occupied billing buckets,
creates a tail reference and invoice, preserves exact transaction dates, records the
complete audit graph, verifies integrity, and recalculates balances.

The service-only SQL trace found 107 `AuditOperation Load` statements inside one
`ReallocationApply#call`. Every financial version resolved the same immutable audit
operation repeatedly. Reference lookup and final graph verification also rematerialized
the same destination references and projection totals.

## Change

- Cache the persisted `AuditOperation` inside the root `Audit::Current` boundary and
  share it through nested mutation-source scopes.
- Discard a cached operation whose transaction rolled back before reusing it.
- Validate `AuditVersion#operation_id` directly and rely on the existing non-null,
  restricted PostgreSQL foreign key for parent existence instead of loading the parent
  once per version.
- Materialize destination references once per reallocation.
- Eager-load verification parents and verify each projection total once after all
  mutation work is complete.

## Comparable Result

Fixed seed `20260914`, exact example
`spec/services/reference_merges/reallocation_apply_spec.rb:126`:

| Measurement | Before | After | Change |
| --- | ---: | ---: | ---: |
| Example duration | 2.371955s | 2.071973s | -12.6% |
| Uncached SQL | 2,233 | 2,048 | -185 (-8.3%) |
| `AuditOperation Load` | 194 | 13 | -181 |
| `Reference Load` | 24 | 20 | -4 |
| Factory count | 55 | 55 | unchanged |
| `AuditVersion Create` | 128 | 128 | unchanged |
| `AuditOperation Create` | 76 | 76 | unchanged |

The whole-example operation counts include fixture construction. At the production
service boundary, `AuditOperation Load` fell from 107 to 1. A non-timing assertion now
guards that bound. Separate operation coverage proves nested work returns the identical
cached object and that rollback replaces a non-persisted cache entry.

Audit completeness, mutation sources, reference/invoice routing, integrity failure
rollback, paid projection handling, balance recalculation, and retry behavior remain
covered by the complete audit and reference-merge regression sets.

## Validation

The final fixed-seed profiling gate completed on 2026-09-15 with 2,107 examples,
zero failures, and 92.52% line coverage. Non-transactional concurrency examples now
truncate their committed records after each example, and order-sensitive financial
specs establish canonical friendships, conversations, acting users, and record scopes
explicitly instead of inheriting incidental suite state.
