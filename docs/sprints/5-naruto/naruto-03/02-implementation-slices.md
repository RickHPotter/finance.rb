# NARUTO-03 — Implementation status and remaining slices

This file maps the V1 work to the current tree. It is not a claim that the full
acceptance matrix or production deployment has passed. The remaining work is specified
in the [V2 development plan](04-v2-development-plan.md).

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

The default public Active Storage routes are disabled. Blob delivery now goes through
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
coverage from pending checks. Once V2 code is complete, run focused specs and
`bin/ci` with the test environment loaded as required by the repository. A clean
test run alone cannot prove a production storage mount; verify that separately.
