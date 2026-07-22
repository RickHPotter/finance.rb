# Deployment and operations runbook

## Rollout boundary

Audit capture and rollback availability are separate controls. Every model in the
initial audited scope continues to write `AuditOperation` and `AuditVersion` rows even
when it has no entry in `Audit::Rollback::Registry`. The initial rollback registry
contains only ordinary cash/card transactions and their installments. Generated
exchange, advance, shared-return, subscription, investment, and Piggy Bank graphs stay
read-only until their complete graph adapter is implemented and covered.

There is no audit backfill. Row counts begin at zero when the storage migration is
applied, and records created before deployment have no synthetic history.

## Deployment order

1. Record the current application revision, database size, and migration start time.
2. Apply the audit storage, message linkage, and rollback idempotency migrations before
   starting application processes that contain the matching models.
3. Verify both append-only triggers, payload constraints, foreign keys, and audit
   indexes before admitting write traffic.
4. Deploy the application processes and restart background workers so request and job
   audit boundaries use the same revision.
5. Create one disposable financial record, update it, and destroy it. Verify the three
   versions share the intended owner/context and operation boundaries.
6. Verify ordinary-user owner scoping and administrator-global history access.
7. Preview and apply one supported rollback, then verify one deliberately stale preview
   is rejected without business versions.

Use the normal migration command and retain its wall-clock output:

```sh
/usr/bin/time -f 'audit migration elapsed=%E max_rss=%MKB' bin/rails db:migrate
```

The local empty-database run on 2026-07-22 created the rollback idempotency index in
11.8 ms. This is not a production estimate. The index migration uses `CREATE UNIQUE
INDEX`, so it must be timed on a production-sized staging copy if audit rows already
exist. A first deployment applies the index before application audit traffic starts.

## Database verification

Both trigger rows must exist with `tgenabled = 'O'`:

```sql
SELECT tgrelid::regclass AS table_name, tgname, tgenabled
FROM pg_trigger
WHERE tgname IN (
  'audit_operations_append_only',
  'audit_versions_append_only'
)
ORDER BY tgname;
```

Verify the expected constraints and indexes from PostgreSQL rather than relying only
on `db/structure.sql`:

```sql
SELECT conrelid::regclass AS table_name, conname, contype
FROM pg_constraint
WHERE conrelid IN ('audit_operations'::regclass, 'audit_versions'::regclass)
ORDER BY table_name, conname;

SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE tablename IN ('audit_operations', 'audit_versions')
ORDER BY tablename, indexname;
```

Direct `UPDATE` and `DELETE` probes belong only in an isolated staging transaction.
They must fail with `<table> is append-only`. Never run a destructive probe against a
production audit row.

## Query-plan baseline

The 2026-07-22 local baseline contained zero operations and zero versions. Total
relation sizes were 72 kB for `audit_operations` and 64 kB for `audit_versions`.
Natural `EXPLAIN (COSTS OFF)` plans selected:

- `index_audit_versions_on_owner_id_and_created_at` for owner history
- `index_audit_versions_on_item_type_and_item_id_and_created_at` for record history
- `index_audit_operations_on_source_and_created_at` for source chronology

The empty baseline verifies index eligibility, not production selectivity. Capture
`EXPLAIN (ANALYZE, BUFFERS)` on staging after representative data volume exists. Do not
run `ANALYZE` plans for mutating statements.

## Growth monitoring

Audit data is retained indefinitely. Monitor rows, total relation size, average payload
size, and the age of the newest insert without deleting old history:

```sql
SELECT
  (SELECT count(*) FROM audit_operations) AS operation_rows,
  (SELECT count(*) FROM audit_versions) AS version_rows,
  pg_total_relation_size('audit_operations') AS operation_bytes,
  pg_total_relation_size('audit_versions') AS version_bytes,
  (SELECT max(created_at) FROM audit_operations) AS newest_operation_at,
  (SELECT max(created_at) FROM audit_versions) AS newest_version_at;

SELECT
  avg(pg_column_size(object)) FILTER (WHERE object IS NOT NULL) AS avg_object_bytes,
  max(pg_column_size(object)) FILTER (WHERE object IS NOT NULL) AS max_object_bytes,
  avg(pg_column_size(object_changes)) FILTER (WHERE object_changes IS NOT NULL) AS avg_changes_bytes,
  max(pg_column_size(object_changes)) FILTER (WHERE object_changes IS NOT NULL) AS max_changes_bytes
FROM audit_versions;

SELECT result, count(*)
FROM audit_operations
WHERE source = 'rollback' AND created_at >= now() - interval '24 hours'
GROUP BY result
ORDER BY result;
```

Alert when a trigger is absent/disabled, inserts stop while financial writes continue,
payload-limit failures rise, rollback failures rise, or relation growth materially
departs from the application transaction rate. Table and index bloat remediation must
preserve every logical audit row.

## Application rollback

Roll back application code without reversing the audit migrations. Do not run the
audit migration `down` path, drop triggers, remove constraints, or truncate history.
An older application revision may ignore these tables, but already-written history
remains readable through SQL and becomes available in the UI again when the auditing
revision is restored.

Hiding history or rollback routes must not remove `FinancialAuditable` from models.
Disabling a rollback family means removing or withholding its registry entry, not
disabling PaperTrail. Failed rollout diagnosis should use new corrective migrations;
immutable rows are not edited in place.

## Manual UI gate

Check English and Portuguese on desktop and mobile widths in both light and dark mode:

- operation index pagination and filters remain usable at 25, 50, and 100 rows
- operation detail and record timelines disclose raw JSON only inside collapsed details
- destroyed records remain discoverable through their record timeline URL
- ordinary users cannot see another owner's operation, version, metadata, or raw payload
- administrators can inspect mixed-owner operations and open rollback previews
- unsupported or generated graphs show a read-only preview without an apply form
- supported previews show the complete change set and require paid-history confirmation
- a successful apply redirects to the new rollback operation
- a stale apply returns to the preview with a localized rejection

Record the tested revision, locale, viewport, theme, operation ID, and rollback result in
the deployment log.
