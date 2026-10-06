# NARUTO-03 — Transaction attachments: product and data contract

## Status and scope

V1 is implemented in the current tree. This contract records the intended behavior and
the remaining gaps as reviewed on 2026-10-06. The [V2 development plan](04-v2-development-plan.md)
covers security, durable storage, deletion identity, and missing verification. Fiscal
document extraction remains a separate, deferred feature; it is not part of hardening V2.

## V1 contract

- `CashTransaction`, `CardTransaction`, and `LineItem` each declare
  `has_many_attached :receipts`. Cash and card transactions have upload and display UI.
  Line items have a model-level attachment association only; their upload UI is deferred.
- The accepted types are PDF (`application/pdf`), JPEG (`image/jpeg`), PNG (`image/png`),
  HEIC (`image/heic`), XML (`application/xml` or `text/xml`), and ZIP
  (`application/zip`).
- **Every attachment, including every picture, PDF, XML, and ZIP, is limited to 10 MiB.**
  Every host record is limited to five receipts. Both limits and the content-type
  allowlist are model validations on all three hosts. Client-side checks are feedback,
  not the authoritative limit.
- The installed `active_storage_validations` gem uses this DSL for file size:

  ```ruby
  validates :receipts,
            content_type: %w[application/pdf image/jpeg image/png image/heic application/xml text/xml application/zip],
            size: { less_than_or_equal_to: 10.megabytes },
            limit: { max: 5 }
  ```

- Cash and card forms upload files with Active Storage `DirectUpload` and Stimulus.
  Progress bars update in the browser while each file uploads. A completed upload adds
  its signed blob ID to a hidden form field. The transaction is attached when the form
  saves; selecting or uploading a file alone does not save the transaction.
- The attachment picker and existing-file list live in
  `Components::TransactionReceiptsUpload`, presented in a modal from each transaction
  form. `Components::TransactionReceiptsList` renders filenames, downloads, and delete
  controls on each show page. Paperclip badges live in the cash/card installment rows.
- Attaching a file is not a financial mutation. Deleting one creates an audit annotation
  containing its blob key. Rolling back a financial transaction does not restore or
  remove receipt files. The deletion audit annotation itself has no financial
  compensation.

## Storage and security boundary

The schema already contains the Active Storage tables. `development` and `production`
select the `:local` Disk service, whose configured root is `storage/`; `test` selects
`:test` under `tmp/storage/`. This describes configuration, **not** proof of durable
production storage. Kamal now declares separate production and homolog volumes at
`/rails/storage`, the configured Active Storage root. Those mounts have not yet been
validated across a deployment or backup/restore; do not treat production receipts as
durable until those checks pass.

Receipt downloads and deletes now use authenticated app routes and attachment IDs;
the default public Active Storage routes are disabled. Authenticated blob delivery
retains avatar display. Direct uploads require authentication, enforce the declared
MIME and 10 MiB limits, and bind their signed IDs to the uploader. Content sniffing
and several adversarial failure cases remain V2 release checks.

## Deferred fiscal extraction

Parsing NF-e XML or a cupom fiscal QR URL to suggest an entity, line items, and a
transaction total is deferred. It depends on composite transactions from NARUTO-02.
The future design must assess what issuer, recipient, and URL data can leave the
application before using a third-party service. OCR and bank statement parsing are
also outside NARUTO-03.

## Reconciled contradictions

| Previous statements | Resolution |
|---|---|
| The sprint required 10 MB and five files per record; a detailed slice exempted `LineItem`. | All three models enforce the same rules, even without LineItem UI. |
| The example used `size: { max: 10.megabytes }`; the installed gem requires a comparison key. | Use `size: { less_than_or_equal_to: 10.megabytes }`. `limit: { max: 5 }` remains valid. |
| An appended draft said no model had attachments and production should use object storage, while the resolved section said attachments and local disk already existed. | The appended draft is removed. The current models and configured services are recorded above; durable production storage remains a V2 requirement. |
| The old draft reopened audit, rollback, and fiscal-extraction timing questions after they were marked resolved. | Attachment deletion is annotated without file rollback; fiscal extraction stays deferred. V2 is reserved for attachment hardening. |
| The plan described a future audit version from a touch. | Deletion now writes an explicit audit annotation in the same DB transaction as detaching; Active Storage purges after commit. V2 still needs failure-path and duplicate-audit checks. |

See [implementation status](02-implementation-slices.md) and
[decisions and test matrix](03-decisions-and-test-matrix.md).
