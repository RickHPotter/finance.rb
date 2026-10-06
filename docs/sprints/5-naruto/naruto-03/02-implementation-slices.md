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

Touchpoints: both transaction controllers and `app/views/{cash,card}_transactions/form.rb`.
V2 must guard direct-upload creation on the server, verify the file before storage,
handle unused uploaded blobs, and cover interrupted and failed submissions.

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

`resources :attachments, only: %i[destroy], param: :blob_signed_id` currently
provides `DELETE /attachments/:blob_signed_id` and `attachment_path(signed_id)`.
`AttachmentsController` verifies the record owner, purges the attachment, and then
creates an `AuditVersion` with `attachments_deleted` metadata. It responds with a
Turbo Stream row removal or an HTML redirect.

This route uses a blob signed ID and `find_by(blob_id:)`; it does not uniquely identify
an attachment. The audit write also follows the purge. Both paths require V2 repair.
The final V2 route should identify the attachment, resolve its parent through an
allowed transaction host, and authorize against the current user and context.

## Slice 5 — Verification and release gate

Existing tests cover cash/card model limits, transaction update uploads, badges,
show-page links, and owner/non-owner deletion. There is no dedicated download
authorization test, shared-blob deletion test, LineItem limit test in the prior V1
matrix, browser upload failure test, or confirmed deployment storage check.

The [decisions and test matrix](03-decisions-and-test-matrix.md) separates current
coverage from pending checks. Once V2 code is complete, run focused specs and
`bin/ci` with the test environment loaded as required by the repository. A clean
test run alone cannot prove a production storage mount; verify that separately.
