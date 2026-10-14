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
7. V2 implements authenticated receipt downloads, direct-upload authorization, and
   an attachment-specific delete identifier. Signed avatars remain available to
   authenticated users; anonymous Active Storage delivery is disabled.
8. Parsing a Brazilian cupom fiscal into transaction line items is planned NARUTO-03
   V3 scope and is required for the feature to be called complete. It prefills an
   unsaved NARUTO-02 transaction draft; the user reviews and saves it. The
   `naruto-03-v2` branch targets this scope. Uploaded fiscal XML/PDF/images, QR URLs,
   and 44-digit access keys are intended inputs. A short cupom number is not a lookup
   key; official SEFAZ item retrieval depends on a supported consultation path.

## Current tests and gaps

| Concern | Existing evidence | Required V2 verification |
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
| Fiscal receipt import | No parser or transaction-prefill workflow exists yet. | Implement and test supported XML, PDF/image, QR URL, and 44-digit key inputs; state-specific official lookup feasibility; OCR fallback for printed fiscal receipts; draft line-item prefill, total reconciliation, and user review; see [V3 plan](05-v3-brazilian-fiscal-import-plan.md). |

## Release gate

The attachment baseline is implemented. V2 is complete only when the security and
storage checks above pass, the homolog deployment is healthy, the attachment route is
unambiguous, and `bin/ci` is green. NARUTO-03 as a whole remains incomplete until V3
fiscal import is implemented and its extraction/reconciliation tests pass. Do not mark
either gate complete based on model or request specs alone.
