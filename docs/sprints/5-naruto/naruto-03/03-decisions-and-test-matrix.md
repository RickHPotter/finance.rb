# NARUTO-03 — Decisions and verification matrix

## Product decisions

1. Cash and card transactions have upload, list, badge, and delete UI. `LineItem`
   has the attachment association and the same model limits, with no V1 upload UI.
2. Allowed MIME types are PDF, JPEG, PNG, HEIC, XML, and ZIP as enumerated in the
   [contract](01-product-and-data-contract.md). The limit is **10 MiB per attached
   file of any allowed type**, and five attached files per host record.
3. `active_storage_validations` enforces these rules on all three models.
   Its size comparison is `less_than_or_equal_to: 10.megabytes`; its attachment-count
   syntax is `limit: { max: 5 }`.
4. Browser progress is rendered by Stimulus during Active Storage direct upload.
   Turbo streams update the page after deletion; they do not report upload progress.
5. Attachment files are documentary evidence. Financial rollback does not alter them.
   Deletion must leave an audit annotation, while the annotation has no financial
   compensation.
6. Production currently selects local Disk storage. Persistence across deploys is
   unverified in this repository and is a V2 release gate.
7. Authenticated receipt downloads, direct-upload authorization, and an
   attachment-specific delete identifier are V2 requirements.

## Current tests and gaps

| Concern | Existing evidence | Required V2 verification |
|---|---|---|
| Cash/card model validation | `spec/models/cash_transaction_spec.rb`, `spec/models/card_transaction_spec.rb` cover allowed, disallowed, oversized, and sixth attachments. | Boundary at exactly 10 MiB, if not covered. |
| LineItem model validation | Prior spec only checked attachment reflection. | Allowed, disallowed, oversized, and sixth attachments; no UI dependency. |
| Cash/card form upload | Request specs submit files on update. | Create flow, failed form, interrupted upload, and cleanup of unattached blobs. |
| Badge and show list | Request specs inspect both transaction index/show pages. | Assert query count stays bounded as rows increase. |
| Delete ownership and audit | `spec/requests/attachments_spec.rb` covers owner deletion, non-owner 403, and a cash audit annotation. | Shared blob attached to two records, cross-context access, audit failure, exactly one audit annotation, and rollback behavior. |
| Download | Show-page specs check that a link is rendered. | Owner gets file; anonymous, other user, and wrong context cannot download it. |
| Direct upload | Stimulus controller and form wiring exist. | Anonymous upload is rejected; MIME and byte size are checked before blob creation; oversized or unsupported files do not reach storage. |
| Storage durability | Service configuration names local Disk. | Deployed mount or durable service is verified, including a redeploy and backup/restore exercise. |

## Release gate

V1 model limits are complete only when all three models and their focused specs
pass. V2 is complete only when the security and storage checks above pass, the
attachment route is unambiguous, and `bin/ci` is green. Do not mark those V2
items complete based on model or request specs alone.
