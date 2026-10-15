# NARUTO-03 — Transaction attachments: product and data contract

## Status and scope

NARUTO-03 is not complete yet. Receipt attachments and the first fiscal-import flow
are implemented. Desktop cash/card index pages expose an import action beside New;
the PWA exposes it as a floating action above the New button. Both open the same modal,
which accepts authorized XML, a complete Goiás signed QR URL, a Paraná NFC-e key/QR
URL or 44-digit key, PDF text, and an image/camera QR scan. Supported sources prefill
an unsaved transaction draft with line items. The modal defaults to Goiás, and line-item category/entity
defaults can be applied in bulk then edited for exceptions. Imported files can be kept
as transaction receipts. The custom file picker shows the selected filename and keeps
"Import file" disabled until a file is selected.

The persisted receipt inbox supports collecting cupoms on a phone and completing
transactions later on a PC without creating incomplete financial transactions.
Preserve the uploaded XML/PDF/photo as the source attachment; key/URL-only imports
keep a private JSON source manifest. For Goiás QR imports, retain readable, self-contained
HTML snapshots of the verified DANFE and detailed consultation views, plus a structured
JSON snapshot derived from the detailed page. The HTML snapshots strip remote scripts
and assets so downloaded copies remain usable offline; they are not byte-for-byte SEFAZ
responses or signed fiscal XML. Transfer the source and
consultation evidence to the final transaction only when its normal save succeeds.
See the V3 plan's saved-inbox and evidence requirements.

The first persisted receipt-inbox workflow is implemented: a cupom can be saved on one
device and opened later in either cash or card transaction form; the uploaded source or
a generated JSON manifest, plus available Goiás consultation evidence, becomes
transaction attachments only after successful save. The user reports the supported
cash/card import flows manually tested. Remaining NARUTO-03 work is duplicate-document
protection and the V2 attachment security/failure-path and deployed storage checks.
NF-e model-55 accuracy and fiscal adjustments are [NARUTO-07](../naruto-07/01-product-and-data-contract.md);
OCR from screenshots and documents is [NARUTO-08](../naruto-08/01-product-and-data-contract.md).
Additional state adapters are optional unless separately agreed.

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
- User uploads accept PDF (`application/pdf`), JPEG (`image/jpeg`), PNG (`image/png`),
  HEIC (`image/heic`), XML (`application/xml` or `text/xml`), and ZIP
  (`application/zip`). Fiscal import can also generate a JSON manifest/snapshot
  (`application/json`) and, for Goiás, server-fetched HTML evidence (`text/html`).
  HTML is not accepted through the browser's direct-upload endpoint and is forced to
  download rather than render inline. LineItem receipts do not accept HTML.
- **Every attachment, including every picture, PDF, XML, and ZIP, is limited to 10 MiB.**
  Every host record is limited to five receipts. Both limits and the applicable
  content-type allowlist are model validations. Client-side checks are feedback, not
  the authoritative limit.
- The installed `active_storage_validations` gem uses this DSL for file size:

  ```ruby
  validates :receipts,
            content_type: %w[application/json application/pdf image/jpeg image/png image/heic application/xml text/xml application/zip text/html],
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

## Fiscal receipt import (implemented baseline; remaining work tracked in V3 plan)

The implemented workflow converts supported Brazilian cupom-fiscal sources into
line items in a cash or card draft. It starts from an import modal opened by the
desktop index action or the PWA floating action, not from the transaction form itself.
The draft is unsaved and must be reviewed and completed before normal submission.
Current supported paths and their limits are listed in the V3 plan. A short printed cupom
number is not a usable lookup key on its own. Duplicate detection remains an open
NARUTO-03 bug; OCR and deeper NF-e support have their own features.

OCR of screenshots and photographed receipts is outside this scope and belongs to
NARUTO-08. A readable QR in a receipt photo remains a supported NARUTO-03 input; its
extracted values must be reviewed before saving. Bank-statement parsing remains out
of scope.

## Reconciled contradictions

| Previous statements | Resolution |
|---|---|
| The sprint required 10 MB and five files per record; a detailed slice exempted `LineItem`. | All three models enforce the same rules, even without LineItem UI. |
| The example used `size: { max: 10.megabytes }`; the installed gem requires a comparison key. | Use `size: { less_than_or_equal_to: 10.megabytes }`. `limit: { max: 5 }` remains valid. |
| An appended draft said no model had attachments and production should use object storage, while the resolved section said attachments and local disk already existed. | The appended draft is removed. The current models and configured services are recorded above; durable production storage remains a V2 requirement. |
| Older text treated fiscal extraction as indefinitely out of scope or still wholly planned. | The first fiscal-import paths are implemented and user-tested; duplicate protection stays here, NF-e/adjustment accuracy moves to NARUTO-07, and OCR moves to NARUTO-08. |
| The plan described a future audit version from a touch. | Deletion now writes an explicit audit annotation in the same DB transaction as detaching; Active Storage purges after commit. V2 still needs failure-path and duplicate-audit checks. |

See [implementation status](02-implementation-slices.md) and
[decisions and test matrix](03-decisions-and-test-matrix.md).
