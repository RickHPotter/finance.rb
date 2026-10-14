# NARUTO-03 — Transaction attachments: product and data contract

## Status and scope

NARUTO-03 is not complete yet. The receipt attachment baseline is implemented. V2
security and storage code is in the tree, but its deployment durability and remaining
security/failure-path checks still need verification. Brazilian cupom-fiscal import is
in development: authorized XML, Goiás signed-QR, and Paraná NFC-e key/QR paths now
create reviewable unsaved drafts; PDF text-source and image QR adapters extend the
input options. Printed
item OCR, duplicate protection, and wider state coverage remain open. This separate
V3 workstream is part of the intended NARUTO-03 outcome.

The custom receipt routes disabled Active Storage's defaults, but production-style
boot exposed a route-registration-order collision. The early route-disable fix is in
the tree and route loading was verified locally for both `homolog` and `production`;
the homolog deployment must still be retried and observed healthy.

- [V2 attachment-hardening plan](04-v2-development-plan.md)
- [V3 Brazilian fiscal import plan](05-v3-brazilian-fiscal-import-plan.md)

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
the default public Active Storage routes are disabled at application load so
production-style route initialization cannot add a duplicate default route.
Authenticated blob delivery retains avatar display. Direct uploads require
authentication, enforce the declared MIME and 10 MiB limits, and bind their signed
IDs to the uploader. Content sniffing and several adversarial failure cases remain V2
release checks.

## V3 fiscal receipt import (planned; required for feature completion)

The desired workflow converts a Brazilian cupom fiscal into line items in a cash or
card transaction. V3 depends on NARUTO-02: it should prefill an unsaved transaction
draft with fiscal item descriptions, amounts, and the document total, then let the
user review and complete the line items before saving. See the V3 plan for input
formats, reconciliation rules, security constraints, and open product decisions. The
`naruto-03-v2` branch targets this work despite the existing V3 document label.
Supported inputs should include an uploaded XML, PDF, or image, a QR URL, or a
44-digit access key. A short printed cupom number is not a usable lookup key on its
own. Official SEFAZ consultation is a possible source of item data only when a
supported state/document path permits reliable access; printed fiscal receipt OCR
provides a reviewable fallback when structured data cannot be retrieved.

General OCR of non-fiscal or handwritten receipts and bank-statement parsing remain
outside this scope. A photo of a supported printed fiscal receipt is in scope; its
extracted values must be reviewed before saving.

## Reconciled contradictions

| Previous statements | Resolution |
|---|---|
| The sprint required 10 MB and five files per record; a detailed slice exempted `LineItem`. | All three models enforce the same rules, even without LineItem UI. |
| The example used `size: { max: 10.megabytes }`; the installed gem requires a comparison key. | Use `size: { less_than_or_equal_to: 10.megabytes }`. `limit: { max: 5 }` remains valid. |
| An appended draft said no model had attachments and production should use object storage, while the resolved section said attachments and local disk already existed. | The appended draft is removed. The current models and configured services are recorded above; durable production storage remains a V2 requirement. |
| Older text treated fiscal extraction as indefinitely out of scope. | Fiscal receipt import is now planned V3 scope and required before NARUTO-03 is complete; it remains separate from the V2 attachment-hardening release gate. |
| The plan described a future audit version from a touch. | Deletion now writes an explicit audit annotation in the same DB transaction as detaching; Active Storage purges after commit. V2 still needs failure-path and duplicate-audit checks. |

See [implementation status](02-implementation-slices.md) and
[decisions and test matrix](03-decisions-and-test-matrix.md).
