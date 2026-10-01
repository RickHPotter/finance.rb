# NARUTO-03 — Transaction Attachments & Fiscal Document Integration: Product and Data Contract

## Status

Approved planning contract as of 2026-10-01.

---

## Design Decisions (Resolved)

### D1. What records can carry attachments?

`CashTransaction` and `CardTransaction` are the primary attachment hosts. `LineItem` also receives
`has_many_attached :receipts` at the model level (for future Layer 2 NF-e pre-fill integration),
but **no upload UI is exposed for line items in this sprint**. Attachments are always associated with
the full transaction, not with individual line items.

### D2. How are file type and size limits enforced?

The `active_storage_validations` gem is added to the Gemfile. It provides a clean DSL:

```ruby
validates :receipts,
  content_type: %w[application/pdf image/jpeg image/png image/heic application/xml text/xml application/zip],
  size: { max: 10.megabytes },
  limit: { max: 5 }
```

No custom validator classes are written.

### D3. What storage backend is used?

All environments use the existing ActiveStorage configuration:

| Environment | Service | Root |
|---|---|---|
| `development` | `:local` (Disk) | `storage/` |
| `test` | `:test` (Disk) | `tmp/storage/` |
| `production` | `:local` (Disk) | `storage/` |

Production is confirmed as `:local` disk storage. Cloud backend (S3/GCS) is explicitly out of scope
for this sprint and will be addressed separately when deployment infrastructure requires it.
The existing `has_one_attached :avatar` on `UserProfile` confirms the infrastructure is functional.

### D4. How is receipt deletion handled?

A shared `AttachmentsController` handles deletion:

```
DELETE /attachments/:blob_signed_id
```

The controller locates the `ActiveStorage::Attachment` by the signed blob ID, verifies the parent
record belongs to the current user, purges the blob, and appends the deleted blob key to the parent
transaction's next `AuditVersion` metadata (`{ attachments_deleted: [blob_key] }`). This approach
is reusable across `CashTransaction`, `CardTransaction`, and (in future) `LineItem` without
duplicating logic in each controller.

### D5. How is the UI structured?

Shared Phlex components in `app/components/` are used for both the upload section (used in forms)
and the attachment list section (used in show pages). Both `CashTransaction` and `CardTransaction`
receive full treatment: upload in forms, paperclip badge on index rows, and attachment list on
show pages.

---

## Goal

Allow any `CashTransaction` or `CardTransaction` to carry one or more file **attachments**
(NF-e XML, PDF orçamento, cupom fiscal image, receipt photo, etc.). `LineItem` gets the model
declaration as a foundation for future Layer 2 work. A second layer adds **optical / API
extraction** of item data from a Brazilian NF-e XML or QR-code URL, turning a scanned receipt
into a pre-filled line-item list — deferred to NARUTO-03 V2.

---

## Two Layers

### Layer 1 — Plain attachments (V1, required for this sprint)

Store one or more files against a transaction using `ActiveStorage`, which is already configured
in the application (`active_storage_attachments` and `active_storage_blobs` tables already exist
in the schema). No external API required.

**Supported attachment scenarios**:
- An orçamento PDF for a car maintenance card transaction.
- A receipt photo for a cash transaction.
- The NF-e XML file or a PDF invoice downloaded from the portal do contribuinte.

### Layer 2 — Fiscal document extraction (V2, exploratory — deferred to NARUTO-03 v2)

Parse a Brazilian NF-e XML or follow the QR-code printed on a cupom fiscal (SEFAZ API) and extract:
- Issuer name → Entity suggestion
- Item descriptions → line item descriptions (NARUTO-02)
- Item prices → line item prices
- Total value → parent transaction price pre-fill

This layer depends on NARUTO-02 being available. Deferred.

---

## Non-Goals

- OCR of non-structured receipt images (Layer 2 scope, deferred)
- Bank statement PDF parsing
- Attachment versioning or document management workflow
- Storing attachments for non-transaction records (investments, piggy banks) in this ticket
- Upload UI on `LineItem` level (model-only declaration, UI deferred to Layer 2)
- Cloud storage backend (stays `:local`; infrastructure change is a separate concern)

---

## Current State (confirmed 2026-10-01)

| Item | Status |
|---|---|
| `active_storage_attachments` + `active_storage_blobs` tables | ✅ in schema |
| `ActiveStorage` configured (`:local` dev/prod, `:test` test) | ✅ |
| `has_one_attached :avatar` on `UserProfile` | ✅ existing pattern to follow |
| `active_storage_validations` gem | ❌ not yet in Gemfile — will be added in Slice 1 |
| `LineItem` model (`app/models/line_item.rb`) | ✅ exists (NARUTO-02 already merged) |
| Upload-related Stimulus controller | ❌ none yet — will be created in Slice 3 |
| `AttachmentsController` | ❌ none yet — will be created in Slice 5 |

---

## Proposed Data Model Change (Layer 1)

No new tables. Use `ActiveStorage` polymorphic attach:

```ruby
# On CashTransaction and CardTransaction — full upload UI this sprint
has_many_attached :receipts

# On LineItem (NARUTO-02) — model declaration only; upload UI deferred to Layer 2
has_many_attached :receipts
```

### Storage service

| Environment | Configured Service |
|---|---|
| `development` | `:local` (Disk, `storage/`) |
| `test` | `:test` (Disk, `tmp/storage/`) |
| `production` | `:local` (Disk, `storage/`) |

### Accepted content types

| Type | MIME | Notes |
|---|---|---|
| PDF | `application/pdf` | NF-e, orçamento, invoice |
| JPEG / PNG / HEIC | `image/jpeg`, `image/png`, `image/heic` | Receipt photos |
| XML | `application/xml` / `text/xml` | NF-e XML |
| ZIP | `application/zip` | Batch of NF-e XMLs |

### File size limit

Maximum **10 MB per file**, **5 files per record**. Enforced via `active_storage_validations` gem.

---

## UI Direction

### Upload (transaction create / edit form)

- An "Attachments" section below the main form fields — rendered via a shared Phlex component
  (`app/components/`).
- File picker (multiple files, direct upload enabled).
- Inline preview: `<img>` thumbnail for images; generic icon for PDF / XML.
- Direct upload to ActiveStorage via `@rails/activestorage` `DirectUpload` API (Stimulus controller:
  `attachment-upload-controller`).
- Per-file progress bar while upload is in flight.
- Remove button on each pending file (removes signed blob ID from hidden field).

### Display (transaction index row)

- A paperclip icon badge on transaction rows that have attachments (`.receipts.attached?`).

### Display (transaction show page)

- Attachment list section (shared Phlex component) showing filenames, download links, and
  a per-file delete button.
- Delete calls `DELETE /attachments/:blob_signed_id` on the shared `AttachmentsController`.

### Audit

- Attaching a file is captured by ActiveStorage's own record creation (no custom audit version
  needed for attach).
- Deleting a file appends `{ attachments_deleted: [blob_key] }` to the parent transaction's
  next `AuditVersion` metadata via a `touch` + version write triggered by the delete action.
- Rolling back a transaction does **not** remove its attachments; attachments are documentary
  evidence, not financial mutations.

---

## Layer 2 — NF-e / Cupom Fiscal Extraction (Exploratory, Deferred)

### Brazilian NF-e XML extraction

1. User uploads an NF-e XML file.
2. Server parses with `Nokogiri`.
3. Extracted fields:
   - `<emit><xNome>` → suggested entity name
   - `<det><prod><xProd>` + `<vProd>` → line items
   - `<total><ICMSTot><vNF>` → total value
4. Returns a JSON payload for the form to pre-fill line items (NARUTO-02).

### Cupom fiscal QR code

1. User scans or pastes the QR-code URL (printed at the bottom of a cupom fiscal).
2. Server fetches the SEFAZ state endpoint (varies per state, e.g. SP: `nfe.fazenda.sp.gov.br`).
3. Parses the returned HTML or XML for item data.
4. Same pre-fill flow as NF-e.

### External API notes

- SEFAZ endpoints are public but require valid certificate chains and rate-limit aggressively.
  Use an intermediary service (e.g., `nfe.io`, `focusnfe`) or the direct state endpoint depending
  on budget/complexity.
- External API calls must be wrapped in a background job (Solid Queue already in use).
- No PII should be forwarded to third-party APIs; only the QR-code URL or NF-e XML content
  (which is already a public fiscal document).

---

## Implementation Slices (Layer 1)

See [02-implementation-slices.md](02-implementation-slices.md) for detailed steps, primary
touchpoints, and acceptance criteria for each slice.

Summary:

| Slice | Description |
|---|---|
| 1 | `has_many_attached :receipts` + `active_storage_validations` gem on all three models |
| 2 | Permit `receipts: []` params in `CashTransactionsController` and `CardTransactionsController` |
| 3 | `attachment-upload-controller.js` (Stimulus, DirectUpload) + shared upload-section Phlex component |
| 4 | Paperclip icon badge on cash + card transaction index rows |
| 5 | `AttachmentsController` (`DELETE /attachments/:blob_signed_id`) + shared attachment-list Phlex component in show pages |
| 6 | Model specs + request specs |

---

## Open Questions

All product-level questions were resolved during planning on 2026-10-01. See
[03-decisions-and-test-matrix.md](03-decisions-and-test-matrix.md) for the full decision log.


---

## Goal

Allow any transaction (cash or card) and any line item (NARUTO-02) to carry one or
more file **attachments** (NF-e XML, PDF orçamento, cupom fiscal image, receipt photo,
etc.). A second layer adds **optical / API extraction** of item data from a Brazilian
NF-e XML or QR-code URL, turning a scanned receipt into a pre-filled line-item list.

---

## Two Layers

### Layer 1 — Plain attachments (V1, required for this sprint)

Store one or more files against a transaction or line item using
`ActiveStorage`, which is already configured in the application
(`active_storage_attachments` and `active_storage_blobs` tables already exist in the
schema). No external API required.

**Supported attachment scenarios**:
- An orçamento PDF for a car maintenance card transaction.
- A receipt photo for a cash transaction.
- The NF-e XML file or a PDF invoice downloaded from the portal do contribuinte.

### Layer 2 — Fiscal document extraction (V2, exploratory — deferred to NARUTO-03 v2)

Parse a Brazilian NF-e XML or follow the QR-code printed on a cupom fiscal (SEFAZ
API) and extract:
- Issuer name → Entity suggestion
- Item descriptions → line item descriptions (NARUTO-02)
- Item prices → line item prices
- Total value → parent transaction price pre-fill

This layer depends on NARUTO-02 being available. Deferred.

---

## Non-Goals

- OCR of non-structured receipt images (Layer 2 scope, deferred)
- Bank statement PDF parsing
- Attachment versioning or document management workflow
- Storing attachments for non-transaction records (investments, piggy banks) in this ticket

---

## Current State

`ActiveStorage` is configured. No model currently calls `has_one_attached` or
`has_many_attached`. The infrastructure (tables, service configuration) already exists.

---

## Proposed Data Model Change (Layer 1)

No new tables. Use `ActiveStorage` polymorphic attach:

```ruby
# On CashTransaction and CardTransaction
has_many_attached :receipts

# On LineItem (NARUTO-02)
has_many_attached :receipts
```

### Storage service

Confirm and document which ActiveStorage service (`:local`, `:amazon`, `:gcs`) is
used in each environment. Production should use an object storage backend.

### Accepted content types

| Type | MIME | Notes |
|---|---|---|
| PDF | `application/pdf` | NF-e, orçamento, invoice |
| JPEG / PNG / HEIC | `image/*` | Receipt photos |
| XML | `application/xml` / `text/xml` | NF-e XML |
| ZIP | `application/zip` | Batch of NF-e XMLs |

### File size limit

Maximum **10 MB per file**, **5 files per record**. Enforced with ActiveStorage
validations (via the `active_storage_validations` gem or custom validator).

---

## UI Direction

### Upload (transaction create / edit form)

- A "Attachments" section below the main form fields.
- File picker (drag-and-drop on desktop, native picker on mobile).
- Inline preview thumbnail for images; generic icon for PDF / XML.
- Direct upload to ActiveStorage via JavaScript (no full-page reload).
- Turbo-streamed progress indicator.

### Display (transaction show / index row)

- A paperclip icon badge on transaction rows that have attachments.
- Expanded detail shows a list of attachment filenames with download links and
  a delete button (audited, triggers a version event).

### Audit

- Attaching a file = `create` event on the `ActiveStorageAttachment` record.
  Because ActiveStorage attachments are not PaperTrail-tracked by default, track
  attachment actions via a thin `TransactionAttachment` join model or log the
  blob key in the parent transaction's audit metadata.
- Deleting a file = `destroy` event.

---

## Layer 2 — NF-e / Cupom Fiscal Extraction (Exploratory, Deferred)

### Brazilian NF-e XML extraction

1. User uploads an NF-e XML file.
2. Server parses with `Nokogiri`.
3. Extracted fields:
   - `<emit><xNome>` → suggested entity name
   - `<det><prod><xProd>` + `<vProd>` → line items
   - `<total><ICMSTot><vNF>` → total value
4. Returns a JSON payload for the form to pre-fill line items (NARUTO-02).

### Cupom fiscal QR code

1. User scans or pastes the QR-code URL (printed at the bottom of a cupom fiscal).
2. Server fetches the SEFAZ state endpoint (varies per state, e.g. SP: `nfe.fazenda.sp.gov.br`).
3. Parses the returned HTML or XML for item data.
4. Same pre-fill flow as NF-e.

### External API notes

- SEFAZ endpoints are public but require valid certificate chains and rate-limit
  aggressively. Use an intermediary service (e.g., `nfe.io`, `focusnfe`) or the
  direct state endpoint depending on budget/complexity.
- External API calls must be wrapped in a background job (Solid Queue already in use).
- No PII should be forwarded to third-party APIs; only the QR-code URL or NF-e XML
  content (which is already a public fiscal document).

---

## Implementation Slices (Layer 1)

### Slice 1 — ActiveStorage setup validation & model attachment
- Confirm storage service configuration across environments.
- Add `has_many_attached :receipts` to `CashTransaction`, `CardTransaction`, `LineItem`.
- Add file size and type validators.
- Add `content_type_allowlist` and `byte_size_limit` validations.

### Slice 2 — Upload UI and direct upload
- Phlex component for the attachment upload section (drag-and-drop, file list,
  inline preview, Turbo-streamed progress).
- Stimulus controller: `attachment-upload-controller`.

### Slice 3 — Display and delete
- Attachment list on transaction show.
- Delete action (audited via metadata in parent transaction version).
- Paperclip badge on index rows.

### Slice 4 — Specs
- Model specs: validation, content type rejection, size rejection.
- Request specs: upload, download, delete.

---

## Open Questions

1. **Layer 2 timing** — should Layer 2 be scoped into this sprint or treated as a
   separate NARUTO-03-v2 ticket? Proposal: **separate ticket**, keep this sprint's
   scope to Layer 1 only.
2. **Audit granularity** — should each attachment get its own `AuditVersion` record,
   or is it sufficient to note it in the parent transaction's metadata?
   Proposal: **parent metadata annotation** for simplicity; full versioning deferred.
3. **Rollback** — can a user roll back a transaction and have attachments removed?
   Proposal: **attachments are not rolled back** (they are evidence, not financial
   mutations). The rollback adapter for `CashTransaction`/`CardTransaction` skips blobs.
