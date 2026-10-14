# NARUTO-03 — Implementation status and remaining slices

This file maps the implemented attachment baseline and remaining NARUTO-03 work.
Receipt attachment support is implemented; V2 deployment/security verification and V3
Brazilian fiscal import are still open. The fiscal import now has working XML and
Paraná key/QR draft-prefill paths, but printed item OCR, duplicate protection, and
wider coverage remain. NARUTO-03 should not be marked complete until both workstreams
meet their acceptance criteria.

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
verified in `homolog` and `production`; the failed homolog deployment has not yet been
retried. Blob delivery now goes through
an authenticated controller that checks receipt ownership/context (and preserves
authenticated avatar delivery). Direct-upload disk-service routes remain for the
upload protocol. Operational reconciliation for a post-commit storage purge failure
and audit-failure request coverage are still pending.

## Slice 5 — Verification and release gate

Existing tests cover cash/card model limits, transaction update uploads, badges,
show-page links, LineItem limits, authorized receipt download, owner/non-owner
deletion, and oversized/anonymous direct-upload rejection. Shared-blob deletion,
wrong-context coverage, browser upload failure paths, audit failure, and confirmed
deployment storage checks are still pending.

The [decisions and test matrix](03-decisions-and-test-matrix.md) separates current
coverage from pending checks. A clean test run alone cannot prove a production storage
mount; verify that separately.

## Slice 6 — Production-style route boot and deployment verification

The duplicate Active Storage route failure was reproduced locally under both
`RAILS_ENV=homolog` and `RAILS_ENV=production`. `ActiveStorage.draw_routes = false` is
now set when the application is configured, in addition to
`config.active_storage.draw_routes = false`. Both environments now load the custom
authenticated receipt route locally. Retrying homolog and confirming container health
is still required.

## Slice 7 — Brazilian cupom-fiscal import to transaction line items

Partially implemented. This remains required for completing NARUTO-03.
The [V3 plan](05-v3-brazilian-fiscal-import-plan.md) defines the intended flow: read a
supported fiscal XML, PDF/image, QR URL, or 44-digit access key; retrieve item details
from an official consultation where feasible or extract a printed receipt locally;
prefill the NARUTO-02 cash/card transaction form; reconcile its total; and require
user review before saving. A short cupom number alone is insufficient. Fiscal
extraction is separate from attachment hardening V2. The `naruto-03-v2` branch targets
this slice; the V3 document label predates the branch name. Authorized XML,
Paraná NFC-e key/QR lookup, PDF text-key extraction, and image QR scanning now prefill
unsaved cash/card drafts. OCR when the printed receipt has no usable QR/key,
duplicate-document protection, and additional state adapters are not yet implemented.
