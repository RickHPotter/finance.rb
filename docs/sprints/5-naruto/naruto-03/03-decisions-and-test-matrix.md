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
6. Production currently selects local Disk storage. The user confirmed V2 deployment
   and backup checks complete on 2026-10-28; external verification is not recorded
   in this repository.
7. V2 implements authenticated receipt downloads, direct-upload authorization, and
   an attachment-specific delete identifier. Signed avatars remain available to
   authenticated users; anonymous Active Storage delivery is disabled.
8. The first fiscal-import workflow is implemented on `naruto-03-v2`: cash/card index
   pages launch a modal that accepts authorized XML, a full Goiás signed QR URL, a
   Paraná NFC-e QR URL or 44-digit key, supported PDF text, and a readable image or
   camera QR. Successful imports prefill an unsaved NARUTO-02 transaction draft. The
   user reviews and saves through the normal form. A short cupom number is not a
   lookup key; each official SEFAZ path is state-specific. The modal defaults to
   Goiás, supports Paraná selection, and allows bulk category/entity defaults with
   per-line-item overrides. Blank categories are allowed under the current contract.

## Tests and historical V2 verification checklist

| Concern | Existing repository evidence | Earlier V2 verification checklist |
|---|---|---|
| Cash/card model validation | `spec/models/cash_transaction_spec.rb`, `spec/models/card_transaction_spec.rb` cover allowed, disallowed, oversized, and sixth attachments. | Keep the 10 MiB edge covered. |
| LineItem model validation | `spec/models/line_item_spec.rb` covers allowed, disallowed, oversized, sixth attachment, and exactly 10 MiB. | None for the agreed model contract. |
| Cash/card form upload | Request specs submit files on update. | Create flow, failed form, interrupted upload, and cleanup of unattached blobs. |
| Badge and show list | Request specs inspect both transaction index/show pages. | Assert query count stays bounded as rows increase. |
| Delete ownership and audit | `spec/requests/attachments_spec.rb` covers owner delete, cross-user denial, and cash audit annotation; deletion is scoped to attachment ID. | Shared blob, cross-context, audit failure, exactly one annotation, and rollback behavior. |
| Download | `spec/requests/attachments_spec.rb` covers owner stream and cross-user denial; receipt blob route is authenticated. | Anonymous and wrong-context cases; avatar access regression check. |
| Direct upload | `spec/requests/attachments_spec.rb` covers anonymous and oversized rejection; authenticated controller validates allowlisted MIME and byte size before blob creation. | Unsupported-type request; cross-actor signed blob attach; inspect stored bytes/content type. |
| Storage durability | Production and homolog now have separate named volumes at `/rails/storage`; the storage directories were empty at inspection. | Deploy with the mount, verify persistence across replacement, and exercise backup/restore. |
| Production-style route boot | `config.active_storage.draw_routes = false` plus the early `ActiveStorage.draw_routes = false` prevents default routes from colliding with the authenticated receipt route; local homolog and production route commands boot. | Redeploy homolog and confirm container health and authenticated file/avatar flows. |
| Fiscal receipt import | XML parser, Goiás signed-QR and Paraná key/QR adapters, PDF text-source extraction, image/camera QR scanning, index-page modal, cash/card draft prefill, and bulk category/entity defaults are implemented; service, request, and browser specs cover supported paths. The user reports manual cash/card validation complete. | Duplicate policy/protection and NF-e/total-adjustment analysis moved to NARUTO-07; screenshot/document OCR is NARUTO-08. Additional states are optional; see [V3 plan](05-v3-brazilian-fiscal-import-plan.md). |

## Completion status

The user confirmed V2 attachment hardening and the supported V3 fiscal-import flow
complete on 2026-10-28. The table above records repository evidence and the earlier
V2 checklist, not a new list of release blockers. NARUTO-03 is closed; duplicate
fiscal-document protection moved to NARUTO-07. Reconciliation
and NF-e expansion are NARUTO-07; OCR is NARUTO-08. Broader state coverage should be
tracked separately unless made an explicit release requirement.
