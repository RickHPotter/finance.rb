# NARUTO-03 — Completed implementation slices

This file records the completed attachment and fiscal-import slices of NARUTO-03.
Receipt attachments and the first Brazilian fiscal-import path are implemented. The
import flow is launched from the desktop index action or the PWA floating action on
cash/card index pages, supports authorized XML, Goiás
signed QR, Paraná key/QR, PDF text, and image/camera QR inputs, and fills a reviewable
unsaved draft. The user confirmed V2 attachment hardening and the supported V3 import
phase complete on 2026-10-28. Duplicate protection moved to NARUTO-07. NF-e-specific
accuracy and reconciliation belong to NARUTO-07; OCR without a usable structured
source belongs to NARUTO-08. State expansion is optional unless separately agreed.
NARUTO-03 is closed as of 2026-10-28; duplicate-import protection is NARUTO-07 work.

## Slice 1 — Attachment hosts and model limits

`CashTransaction`, `CardTransaction`, and `LineItem` declare
`has_many_attached :receipts`. The `active_storage_validations` gem is bundled.
All three models must validate the same MIME allowlist, **10 MiB per file**, and
**five files per record**. Use `size: { less_than_or_equal_to: 10.megabytes }`, not
`size: { max: ... }`; the latter is not accepted by the installed gem.

Touchpoints: `Gemfile`, `app/models/cash_transaction.rb`,
`app/models/card_transaction.rb`, `app/models/line_item.rb`.

Verification: model specs for valid, disallowed, oversized, and sixth attachments
on all three hosts. The LineItem cases were missing from the original V1 plan and
are part of the current correction.

## Slice 2 — Cash and card upload flow

Both transaction controllers permit `receipts: []` and attach submitted files during
create or update. The forms include `attachment-upload` on their form element, and
`app/javascript/controllers/attachment_upload_controller.js` performs direct uploads
with browser-side per-file progress and pending-file removal.

The shared `Components::TransactionReceiptsUpload` component is in
`app/components/transaction_receipts_upload.rb`. It renders the modal picker,
existing-file list, and pending upload list. The model-specific hidden field name is
built from the transaction's `model_name.param_key`. Locale keys are in
`config/locales/locale.yml`. The Stimulus controller is registered in
`app/javascript/controllers/index.js`.

V2 now routes direct-upload creation through an authenticated controller, enforces
the MIME allowlist and 10 MiB limit before blob creation, stamps the uploader ID in
trusted metadata, and checks that metadata when a signed blob is submitted to a cash
or card transaction. The form blocks submission while a direct upload is in flight.
An age-based job purges unattached blobs after 24 hours. Actual content sniffing and
browser-level failure-path coverage remain release gaps; the client-declared MIME
type is not proof of file contents.

## Slice 3 — Index and show surfaces

Cash and card paperclip badges are rendered in
`app/views/cash_installments/index.rb` and `app/views/card_installments/index.rb`.
Their relations preload `receipts_attachments` in
`app/services/logic/cash_installments.rb` and
`app/services/logic/card_installments.rb`. The transaction show views call
`TransactionReceiptsList(transaction: ...)` to render
`app/components/transaction_receipts_list.rb`.

Phlex component calls in these views must use the component helpers directly. Do
not add `render Components::X.new(...)` examples to implementation instructions.

## Slice 4 — Delete and audit

`DELETE /attachments/:id` and `GET /attachments/:id/download` now identify one
`ActiveStorage::Attachment`. The controller accepts only `receipts` on cash/card
transactions and authorizes the parent against the current user and context. Unknown
and unauthorized attachments return 404. Deletion detaches one association, writes
its `attachments_deleted` audit annotation in the same database transaction, then
relies on Active Storage's post-commit purge job; a blob still attached elsewhere is
not deleted. The Turbo response removes only that attachment's row.

The default public Active Storage routes are disabled at application load, before
production-style route initialization can draw them. This avoids a duplicate
`rails_service_blob` name with the authenticated app route. Local route boot has been
verified in `homolog` and `production`; the user confirmed V2 deployment checks complete
on 2026-10-28. Blob delivery now goes through
an authenticated controller that checks receipt ownership/context (and preserves
authenticated avatar delivery). Direct-upload disk-service routes remain for the
upload protocol. Operational reconciliation for a post-commit storage purge failure
and audit-failure request coverage were listed as earlier V2 checks; completion was
confirmed by the user, without external verification records in this repository.

## Slice 5 — Verification and release gate

Existing tests cover cash/card model limits, transaction update uploads, badges,
show-page links, LineItem limits, authorized receipt download, owner/non-owner
deletion, and oversized/anonymous direct-upload rejection. Shared-blob deletion,
wrong-context coverage, browser upload failure paths, audit failure, and deployment
storage checks were listed in the earlier V2 acceptance plan. The user confirmed V2
complete on 2026-10-28.

The [decisions and test matrix](03-decisions-and-test-matrix.md) records the earlier
verification checklist. The user confirmed its V2 release checks complete; the
repository does not contain independent evidence for external deployment checks.

## Slice 6 — Production-style route boot and deployment verification

The duplicate Active Storage route failure was reproduced locally under both
`RAILS_ENV=homolog` and `RAILS_ENV=production`. `ActiveStorage.draw_routes = false` is
now set when the application is configured, in addition to
`config.active_storage.draw_routes = false`. Both environments now load the custom
authenticated receipt route locally. Retrying homolog and confirming container health
was part of the V2 release checklist confirmed complete by the user on 2026-10-28.

## Slice 7 — Brazilian cupom-fiscal import to transaction line items

The supported V3 import phase is implemented and user-confirmed complete. Duplicate
protection is a NARUTO-07 follow-up.
The [V3 plan](05-v3-brazilian-fiscal-import-plan.md) defines the intended flow: read a
supported fiscal XML, PDF/image, QR URL, or 44-digit access key; retrieve item details
from an official consultation where feasible or extract a printed receipt locally;
prefill the NARUTO-02 cash/card transaction form; reconcile its total; and require
user review before saving. A short cupom number alone is insufficient. Fiscal
extraction is separate from attachment hardening V2. The `naruto-03-v2` branch targets
this slice; the V3 document label predates the branch name. Authorized XML,
Goiás signed-QR lookup, Paraná NFC-e key/QR lookup, PDF text-source extraction, and
image QR scanning now prefill
unsaved cash/card drafts. The import action is launched from the cash/card index pages
in a modal, with Goiás selected by default and Paraná also selectable. The file picker
has a custom non-overflowing label/filename display, and Import file remains disabled
until a file is selected. The modal also provides a camera QR scanner and controls to
apply category/entity defaults across imported rows before individual exceptions are
edited. Categories may remain blank under the current NARUTO-02 contract.

Moved to NARUTO-07: duplicate-document protection and its product policy.
Printed-item OCR when there is no usable structured source moves to NARUTO-08;
NF-e model-55 hardening and total-adjustment reconciliation move to NARUTO-07.
Additional state adapters require a separate scope decision. Do not describe Goiás key-only lookup as
supported: it needs a complete signed QR URL or authorized XML. See the V3 plan for
the source matrix and release checklist.
