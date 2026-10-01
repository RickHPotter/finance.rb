# NARUTO-03 Transaction Attachments: Decisions and Test Matrix

## Resolved Product Decisions

### D1. What records can carry attachments in this sprint?

**Decision**: `CashTransaction` and `CardTransaction` are the full-featured attachment hosts
(upload UI, index badge, show list). `LineItem` receives `has_many_attached :receipts` at the model
level only — no upload UI is exposed for line items in this sprint. Attachments belong to the
transaction as a whole; the line-item attachment surface is reserved for Layer 2 (NF-e pre-fill).

### D2. How are file type, size, and count limits enforced?

**Decision**: Add the `active_storage_validations` gem. It provides a single `validates :receipts`
call with `content_type:`, `size:`, and `limit:` keys, eliminating the need for custom validator
classes. This is consistent with the intent of the naruto-03 spec: "enforced by model-level
validators (via the `active_storage_validations` gem or custom validator)."

Accepted MIME types: `application/pdf`, `image/jpeg`, `image/png`, `image/heic`,
`application/xml`, `text/xml`, `application/zip`. Max 10 MB per file, max 5 files per record.

### D3. What storage backend is used?

**Decision**: Keep the existing `:local` disk configuration in all environments. Production is
confirmed to be running `:local` (not a cloud backend). The existing `has_one_attached :avatar` on
`UserProfile` confirms the infrastructure is healthy and functional. Cloud backend migration is a
separate infrastructure concern and is out of scope for this sprint.

### D4. How is receipt deletion routed?

**Decision**: A shared `AttachmentsController` at `DELETE /attachments/:blob_signed_id`. This is
preferred over nested `DELETE /cash_transactions/:id/receipts/:blob_signed_id` because:
- Reusable for `CashTransaction`, `CardTransaction`, and future `LineItem` without duplicating
  auth and purge logic.
- The controller resolves the parent record via `ActiveStorage::Attachment#record` (polymorphic),
  checks ownership, purges the blob, and logs the deletion in the parent's audit metadata.
- A single Turbo Stream response removes the attachment row from whichever show page initiated
  the request.

### D5. How is the UI structured?

**Decision**: Shared Phlex components in `app/components/` rather than private methods inside
each view. Two components:
- `TransactionReceiptsUploadComponent` — used in forms (Stimulus-backed, direct upload).
- `TransactionReceiptsListComponent` — used in show pages (download + delete).

Both cash and card transactions receive the full treatment: upload section in create/edit forms,
paperclip badge on index rows, and attachment list section on show pages.

### D6. How is attachment auditing handled?

**Decision**: No standalone `AuditVersion` for attach events (ActiveStorage creates its own join
record). On delete, the `AttachmentsController` touches the parent transaction and appends
`{ attachments_deleted: [blob_key] }` to the parent's next `AuditVersion` metadata. Rolling back
a transaction does not remove its attachments — attachments are documentary evidence, not financial
mutations, so the rollback adapter skips blobs entirely.

---

## Test Matrix

### 1. Model Tests (`spec/models/`)

| File | Scenario | Expected Outcome |
|---|---|---|
| `cash_transaction_spec.rb` | Attach a valid PDF (< 10 MB) | Passes validation |
| `cash_transaction_spec.rb` | Attach a disallowed type (e.g. `.exe`) | Fails with content-type error |
| `cash_transaction_spec.rb` | Attach a file > 10 MB | Fails with size error |
| `cash_transaction_spec.rb` | Attach 6 files at once | Fails with count error |
| `card_transaction_spec.rb` | Attach a valid JPEG (< 10 MB) | Passes validation |
| `card_transaction_spec.rb` | Attach a disallowed type | Fails with content-type error |
| `card_transaction_spec.rb` | Attach a file > 10 MB | Fails with size error |
| `card_transaction_spec.rb` | Attach 6 files at once | Fails with count error |
| `line_item_spec.rb` | `LineItem.reflect_on_attachment(:receipts)` | Returns attachment reflection (not nil) |

### 2. Request Tests (`spec/requests/`)

| File | Endpoint & Action | Scenario | Expected Outcome |
|---|---|---|---|
| `cash_transactions_spec.rb` | `PATCH /cash_transactions/:id` | Submit form with valid receipt file | File attached; `receipts.attached?` → true |
| `cash_transactions_spec.rb` | `GET /rails/active_storage/blobs/…` | Download attached receipt | 200 with correct `content-disposition: attachment` |
| `cash_transactions_spec.rb` | `DELETE /attachments/:blob_signed_id` | Owner deletes own receipt | Blob purged; `receipts.attached?` → false; Turbo Stream response |
| `cash_transactions_spec.rb` | `DELETE /attachments/:blob_signed_id` | Non-owner attempts delete | 403 Forbidden |
| `card_transactions_spec.rb` | `PATCH /card_transactions/:id` | Submit form with valid receipt file | File attached; `receipts.attached?` → true |
| `card_transactions_spec.rb` | `DELETE /attachments/:blob_signed_id` | Owner deletes own receipt | Blob purged; Turbo Stream response |
| `card_transactions_spec.rb` | `DELETE /attachments/:blob_signed_id` | Non-owner attempts delete | 403 Forbidden |

---

## Acceptance Sign-Off Checklist

- [ ] `active_storage_validations` gem added and bundled.
- [ ] `CashTransaction`, `CardTransaction`, and `LineItem` all declare `has_many_attached :receipts`.
- [ ] `CashTransaction` and `CardTransaction` validators reject wrong MIME, oversized files, and > 5 files.
- [ ] `receipts: []` permitted in both controllers' strong params.
- [ ] `attachment-upload-controller.js` Stimulus controller handles DirectUpload with per-file progress.
- [ ] `TransactionReceiptsUploadComponent` renders in cash and card create/edit forms.
- [ ] Paperclip badge appears on index rows for transactions with attachments (no N+1).
- [ ] `AttachmentsController` at `DELETE /attachments/:blob_signed_id` purges blob and guards ownership.
- [ ] `TransactionReceiptsListComponent` renders on cash and card show pages with download + delete.
- [ ] Deleting a receipt appends `{ attachments_deleted: [blob_key] }` to parent transaction audit metadata.
- [ ] Rolling back a transaction does not purge its attachments.
- [ ] All model and request specs pass.
- [ ] `bin/rubocop -A` clean.
- [ ] `bin/ci` green.
