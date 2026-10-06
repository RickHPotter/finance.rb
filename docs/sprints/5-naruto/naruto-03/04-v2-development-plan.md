# NARUTO-03 V2 — Attachment hardening development plan

## Purpose and current baseline

V2 finishes the attachment feature's security and operational contract. It does not
include NF-e, QR-code, or OCR extraction. The V1 [contract](01-product-and-data-contract.md)
and [implementation status](02-implementation-slices.md) describe the current tree.

The three attachment hosts have the 10 MiB per-file, five-file model contract; only
cash and card transactions have UI. V2 code now routes receipt delivery and upload
through authenticated controllers, identifies deletions by attachment, and declares
separate persistent Disk volumes for production and homolog. Remaining code and
operational verification gates are tracked in the
[decision matrix](03-decisions-and-test-matrix.md).

## Slice 1 — Define receipt identity and authorization

1. Introduce attachment-specific routes for the two UI hosts, with a stable
   `ActiveStorage::Attachment` ID or signed attachment ID. Both `GET .../download`
   and `DELETE ...` must address one attachment, not the blob it points to.
2. Resolve only attachments named `receipts` whose record is a `CashTransaction` or
   `CardTransaction`. Authorize the parent against `current_user` **and**
   `current_context`; use the same visibility rule as the transaction show action.
   Reject unattached blobs, other attachment names, unrelated model classes,
   missing records, and mismatched contexts without revealing file metadata.
3. Replace receipt links in `Components::TransactionReceiptsUpload` and
   `Components::TransactionReceiptsList` with these routes. Preserve HTML and Turbo
   behavior for deletion. The implementation disables default Active Storage routes
   and supplies authenticated blob delivery for receipts and authenticated avatar
   delivery; validate other attachment consumers before release.
4. Define the privacy boundary explicitly: if a signed blob URL issued by the old
   UI remains valid, authenticated links alone do not revoke it. Choose and verify
   a route/configuration approach that prevents new and previously issued receipt
   links from bypassing authorization. Inventory avatar and other Active Storage
   consumers before changing global routes.

Acceptance: owner can download/delete a receipt; anonymous users, other users,
wrong contexts, and other attachment names cannot. One blob attached to two records
can be deleted from exactly one authorized record without removing the other.

## Slice 2 — Guard direct upload and unused blobs

1. Replace or wrap `ActiveStorage::DirectUploadsController#create` for receipt uploads
   with application authentication and request-level limits. Validate the declared
   MIME type, a positive byte size no greater than 10 MiB, and any required checksum
   before creating the blob. Keep model validation as the final authority when the
   signed blob is attached.
2. Ensure a signed blob created for one user cannot be attached to another user's
   transaction. Bind receipt upload intent to the actor or verify ownership at
   attach time. Check the actual uploaded content/type as far as the storage service
   allows; client-provided MIME and extension alone are not proof of file type.
3. Prevent form submission while uploads are in flight. Show per-file errors without
   adding failed blobs to hidden fields. Preserve existing attachments on validation
   failure. Define an age-based cleanup job for unattached direct-upload blobs,
   including files removed from the pending list or abandoned with a closed form.
   Do not purge blobs still referenced by any attachment.

Acceptance: anonymous or oversized direct-upload creation fails before storage;
in-flight uploads cannot be lost on submit; failed or abandoned uploads are cleaned
up after the grace period; a signed blob from another actor is rejected.

## Slice 3 — Make deletion audit reliable

1. Replace the blob-based lookup in `AttachmentsController` with the authorized
   attachment from Slice 1. Capture attachment ID, parent, and blob key before purge.
2. Define a single deletion audit event with `attachments_deleted` metadata and
   `mutation_source: "web"`. Confirm that Active Storage's `attachment.purge`
   touch does not generate a second misleading financial version. Keep documentary
   deletion non-compensable by the financial rollback flow.
3. Handle audit failure deliberately: the request must not report success after an
   unrecorded purge. Choose an ordering or durable outbox approach that gives a
   recoverable audit trail despite external file deletion. Specify how operations
   staff reconcile a failed file purge after an audit event.
4. Update the list and edit modal using the attachment identifier so Turbo removes
   only the deleted row. Keep the attachment count correct after a successful delete
   or a rejected request.

Acceptance: exactly one audit annotation identifies each successful deletion;
failed authorization and failed purge create none; an audit failure cannot silently
erase the only evidence; financial rollback neither restores nor removes files.

## Slice 4 — Durable storage and deployment

1. Inspect the actual production and homolog container mounts and current
   `storage/` contents before changing deployment configuration. Document where
   existing avatar and receipt blobs live, and preserve those files during migration.
2. Select a durable backend. For local Disk, enable an explicitly named persistent
   Kamal volume or host mount at the exact `config/storage.yml` root for each
   environment. The Dockerfile uses `WORKDIR /rails`, so the commented
   `/app/storage` example in `config/deploy.yml` is the wrong mount target.
   Keep production and homolog storage separate. If object storage is chosen
   instead, configure credentials, bucket access, backups, and migration of
   existing blobs before switching the service.
3. Verify a file survives app replacement/redeploy, that `ActiveStorage::Blob` rows
   still resolve to bytes, and that backup and restore include the storage data.
   State the recovery procedure and monitoring for missing files.

Acceptance: a deployed upload can be downloaded after a fresh app container starts;
existing avatar files and receipts remain available; backup/restore has been tested.
Local configuration alone does not satisfy this gate.

## Slice 5 — Tests and release gate

- Model specs: all three hosts accept a valid file and reject unsupported MIME,
  files over 10 MiB, and a sixth file. Include exactly 10 MiB as an accepted edge.
- Request specs: cash/card upload create and update, authenticated download and
  deletion, anonymous and cross-user/context denials, shared-blob isolation,
  non-receipt attachment rejection, and audit failure behavior.
- Browser/feature checks: progress, multiple-file selection, removal, failed upload,
  in-flight submit, validation failure, and both transaction form variants.
- Query check: index badges do not introduce per-row attachment queries.
- Rollback service specs: receipt deletion's audit annotation has no financial
  compensation and transaction rollback leaves existing files intact.
- Deployment check: storage survives a new container and can be restored from backup.

Run focused specs after each slice, then `bin/rubocop -A` and `bin/ci` under the
repository's test environment. Do not mark V2 complete until the deployment check
and the security cases pass in addition to CI.

## Explicitly deferred

Fiscal XML parsing, QR-code retrieval, OCR, line-item upload UI, attachment
versioning, and document management are separate product work. Any future fiscal
integration must review recipient and issuer data before sending URLs or XML to an
external service.
