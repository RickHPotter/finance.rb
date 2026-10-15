# NARUTO-03 V3 — Brazilian cupom fiscal to transaction line items

## Status and ownership

**First supported-source slice and persisted receipt inbox implemented; the user reports
manual cash/card validation complete.** Authorized XML prefill, Goiás NFC-e
signed-QR lookup, Paraná NFC-e key/QR lookup, PDF text-source extraction, image/camera
QR scanning, and the cross-device inbox are implemented.
The cash/card index pages launch the import modal. It defaults to Goiás, lets the user
select Paraná, and provides bulk category/entity defaults with per-line-item edits.
The file picker shows its selected filename and keeps Import file disabled until a
file is selected. Duplicate-document protection remains a NARUTO-03 bug. NF-e-specific
accuracy and adjustment analysis move to NARUTO-07; screenshot/document OCR moves to
NARUTO-08. Additional state expansion is optional. This workstream
is distinct from V2 attachment security and deployment hardening. Fiscal data is
translated into an unsaved draft using NARUTO-02's existing `LineItem` form and model;
it does not change the ownership of composite-transaction behavior from NARUTO-02.
The V3 label names the existing document/feature slice, not a required branch name.

## Implemented requirement — saved receipt inbox

An immediate import uses browser `sessionStorage` until the user submits a cash/card
form. The server-persisted **receipt inbox** supports the phone-to-PC workflow: a
user can import a cupom on mobile, save it for
later, collect multiple receipts, then open each on desktop, choose cash or card,
review/edit the prefilled transaction, and submit it normally. Saving an inbox item
must not create a financial transaction or affect balances, installments, or reports.

Treat inbox items as fiscal-receipt drafts, not incomplete `CashTransaction` or
`CardTransaction` rows. This avoids weakening normal transaction validations or
letting incomplete records leak into financial queries. Each saved item stores the
normalized import payload, owner, creation time, and original source attachment where
available. Persist the exact user-uploaded XML/PDF/photo. Retain a camera-captured QR
image only when consultation produced no replacement evidence; when Goiás DANFE, detailed
HTML, or JSON evidence exists, omit the camera image. For a key/URL-only source or an
omitted camera image in the saved inbox, preserve a small JSON source manifest
with the identifier and parsed draft. For Goiás QR imports, additionally preserve
self-contained, script-free HTML snapshots of the official DANFE and detailed consultation
views plus a structured JSON snapshot derived from the detailed page. The HTML files are
readable offline but are not byte-for-byte SEFAZ responses. This JSON is evidence of
the public consultation, not an authorized/signed fiscal XML. Keep each file under the existing 10 MiB and
attachment-count security contract; HTML evidence must download rather than render
inline.

On final transaction save, attach the saved source and any consultation evidence to the resulting cash/card
transaction and consume the inbox item atomically. Explicit deletion removes the saved
item and its attachments. Scope inbox operations to the owner; apply the user's
current context only when creating the final transaction. Never expose a public blob
URL. A user can save multiple items
and process them independently. A failed transaction save must leave the inbox item
available for correction/retry.

## Goal

Let a user start a cash or card transaction from the transaction index and import a
Brazilian cupom fiscal or its supported QR/access key into its item descriptions and
amounts. The user reviews and completes the unsaved draft—including optional
categories, entities, payment instrument, and any unresolved total difference—before
saving. Import must never silently create a financial transaction.

## Inputs and retrieval contract

The desktop entry point is beside the New Cash/Card Transaction actions; the PWA has
a floating receipt-import action above its New button. Both open the same modal, which
accepts an uploaded receipt (XML, PDF, or supported image), a
pasted QR-code URL, or a manually entered **44-digit fiscal access key**. An image or
PDF may contain a QR code, printed key, and/or readable text. The existing 10 MiB
per-file attachment limit applies; ZIP remains an attachment type, but importing its
contents is not supported. The modal also offers live camera QR scanning; it scans for
a QR code and is not OCR/photo text recognition. User-uploaded files are staged as
receipt attachments. A camera-captured QR image is omitted when the backend generated
Goiás DANFE, detailed HTML, or JSON evidence; otherwise it remains a fallback source.
Key/URL-only lookup creates a generated JSON source manifest attachment.

The access key is different from the short sequential `número do cupom`/`nNF` printed
on some receipts. A short number alone is insufficient to identify a document across
issuers and states. The UI must request the 44-digit key or QR code when the user only
has that short number, and allow manual transaction entry as a fallback. Validate key
length, digits, check digit, and supported fiscal model before requesting anything.

Use the best available source in this order, subject to the supported-format matrix:

1. Parse an uploaded authorized fiscal XML locally when available.
2. Extract a QR URL or access key from an uploaded image/PDF, or accept it from the
   user. Query a supported official public consultation only if that state and entry
   path permit a reliable automated request that returns item details.
3. If lookup is unavailable, blocked, or omits items, explain the limitation and allow
   manual entry. OCR of screenshots or printed receipt text is NARUTO-08, not a hidden
   fallback in this feature. Never invent missing items or infer prices from the total.

Direct requests to a SEFAZ public consultation are in scope where technically and
operationally permitted. They are **not** assumed to be a universal API: NFC-e public
consultation is state-run, and some key-entry pages use CAPTCHA. Do not automate
CAPTCHA solving or treat HTML scraping as a stable integration without a state-specific
feasibility check. NF-e `NFeDistribuicaoDFe` is a different, certificate-authenticated
service restricted to interested parties; a user's key alone does not grant this app
access to full XML. Certificate integration requires a separate design for user
eligibility, consent, secret handling, and the service's current rules.

Current implementation and source limitations:

| Input/path | Current behavior | Limitation / fallback |
|---|---|---|
| Authorized NFC-e/NF-e XML | The shared parser accepts a structurally valid authorized `nfeProc` and extracts basic item/total fields locally. | Model-65 examples are tested. Model-55 field accuracy and adjustment coverage need NARUTO-07 hardening; malformed documents return a user-facing error. |
| Goiás NFC-e signed QR URL | Looks up item rows and preserves offline-readable DANFE/detail HTML snapshots plus derived JSON through the official consultation when given the complete QR URL. | A bare GO key cannot be used because the public key-entry page has a browser challenge; provide the QR URL or XML. Public consultation does not provide the original signed XML. |
| Paraná NFC-e QR URL or 44-digit key | Extracts a PR key from the QR URL or accepts a validated 44-digit key, then retrieves item rows via the PR QR path. | State-specific; public consultation/layout changes can cause a safe lookup failure. |
| PDF text | Extracts a GO QR URL or Paraná key from selectable text in the first three pages. | Scanned/image-only PDFs and PDFs without a supported URL/key need NARUTO-08 OCR. |
| JPEG/PNG or camera | Scans a readable QR code and routes its URL/key through the matching supported adapter. | Does not read printed item text. HEIC decoding depends on browser support. No QR means the current importer cannot derive the items. |
| Other states / NF-e key lookup | No generic all-state key lookup is provided. | `NFeDistribuicaoDFe` requires eligible interested-party credentials/certificate; key possession alone is insufficient. Additional state adapters require feasibility and security review. |

Unsupported or inaccessible documents must show a useful explanation and preserve
the user's ability to enter line items manually.

Official starting points: [NFC-e public consultation manual](https://www.nfe.fazenda.gov.br/portal/exibirArquivo.aspx?conteudo=DdSDvm4LtCI%3D),
[PR consultation example with CAPTCHA](https://sped.fazenda.pr.gov.br/NFCe/webservices/sped/nfce/completa),
[PR QR 3.0 layout](https://sped.fazenda.pr.gov.br/NFCe/Pagina/QR-Code),
and [NF-e distribution service specification](https://www.nfe.fazenda.gov.br/Portal/exibirArquivo.aspx?conteudo=U0LlsYVGBRU%3D).
For Goiás, see the [official public consultation](https://nfeweb.sefaz.go.gov.br/nfeweb/sites/nfe/consulta-completa),
the [state's NFC-e consultation rule](https://legisla.casacivil.go.gov.br/pesquisa_legislacao/69865/decreto-9121),
and a [publicly published GO NFC-e example](https://www.camara.leg.br/cota-parlamentar/documentos/publ/3614/2026/8070694.pdf).

## Draft data contract

The implemented first slice extracts the values needed for a basic reviewable draft:

- issuer name, fiscal document model/state, and identifier/access key, when present;
- issue date/time and document total;
- one draft line item per fiscal product/service row, with source description and a
  cent-precision line amount.

The current draft does not retain quantity/unit and the full set of document-level
adjustments as first-class fields. NARUTO-07 investigates these fields, their
financial meaning, and the representation needed for accurate totals.

The importer may suggest the transaction description, date, and total. It does not
guess categories or entities. The user can apply category/entity defaults to all
imported line items, then edit exceptions; categories may be left blank under the
current NARUTO-02 contract. Entity allocation and cash friend-repayment details remain
user-controlled. Keep source row order and show extraction confidence or an explicit
review flag for any NARUTO-08 OCR-derived rows.

The existing split-purchase exact-sum validation prevents saving mismatched amounts.
Do not silently alter product prices to force a match. Analysis of discounts, freight,
other adjustments, and a fuller reconciliation UI belongs to NARUTO-07.

A receipt with one product remains a one-LineItem composite transaction. NARUTO-02's
former two-item minimum was removed for this case; zero active rows still mean a
simple transaction. Price-sum and line-item validations continue to apply.

## User flow

1. From the cash/card transaction index, open **Import receipt**. Choose Goiás or
   Paraná (Goiás is the default), then select a supported file, paste a QR URL, enter
   a 44-digit access key, or use the camera to scan a QR code. **Import file** remains
   disabled until a file is selected.
2. Validate and parse the source; show an explicit loading/progress and error state.
3. Populate an unsaved cash/card transaction draft: date/description/total where
   available, plus editable line-item descriptions and prices.
4. Show source identity and any total mismatch. Allow the user to edit rows, add or
   remove rows, apply category/entity defaults to all rows, change exceptional rows,
   and choose the payment instrument. Categories may remain blank.
5. Save only through the normal transaction form after NARUTO-02 validations pass.
   The successfully imported upload is staged as a receipt attachment; a key or QR
   URL alone must not be represented as an attached file.
6. Detect an already-imported document identifier for the current user/context and
   warn before creating a duplicate. The exact duplicate policy is an open decision.

## Manual-test handoff for the implemented slice

The user reports the supported cash/card paths manually tested. Keep this as a repeatable
regression checklist for future changes. Start from
both `/cash_transactions` and `/card_transactions` index pages, open the import modal,
and use receipts you are entitled to view. Check every imported amount before saving:

1. Upload an authorized NFC-e XML with at least one product and choose **Import
   file**. The new transaction form should switch to Split Purchase and show one editable LineItem
   per product, the issuer as description, and the negative transaction total.
2. Select Goiás, paste the **complete signed Goiás NFC-e QR URL**, then choose **Look up receipt**.
   The official GO consultation should return the itemized rows. A bare GO key should
   explain that GO's key-entry page requires a browser challenge; the short printed
   cupom number should also fail. Then try a Paraná NFC-e 44-digit key or official QR
   URL to verify the older path still works.
3. Upload a text PDF containing the complete Goiás QR URL, or a JPEG/PNG receipt image
   with a readable Goiás QR code. The extracted URL should use the same GO lookup. Also
   test the camera QR control; it scans QR codes only and does not perform OCR.
   A text PDF containing a Paraná key or a PR QR image should still work. The
   user-uploaded file is staged in Attachments after a successful import; wait for its
   upload to finish before saving. A camera capture is skipped when Goiás evidence
   exists. A key/URL-only lookup attaches a generated JSON manifest containing the
   normalized draft, alongside any consultation evidence.
4. Assign categories, review any total difference, and save through the ordinary
   transaction form. A one-product receipt is valid with one LineItem. Adjustment-heavy
   receipts need the NARUTO-07 investigation and should not be assumed to reconcile.

Current limits: Goiás NFC-e lookup needs the complete signed QR URL; Paraná currently
supports key-only lookup. XML parsing is local for structurally supported authorized
NF-e/NFC-e; model-55 accuracy is not yet verified.
Image and camera import need a readable QR; PDF import needs selectable text containing
a supported GO QR URL or PR key in the first three pages. There is no OCR fallback for
printed item rows, scanned PDFs, or images without a QR. HEIC browser decoding depends
on support in the user's browser. Duplicate-document warnings remain pending; additional
state adapters are optional. Lookup can fail if a state's public HTML changes or blocks the
query; manual line-item entry remains the fallback.

## Completion checklist

The user reports manual testing complete for the supported first slice. Remaining
NARUTO-03 gates and deferred work are:

- [x] User manually tested cash/card imports through the supported source and save flows.
- [ ] Decide the duplicate-document policy and implement a warning/protection scoped
  to the agreed user/context behavior.
- [ ] Finish V2 attachment security and durability gates in
  [the attachment plan](04-v2-development-plan.md), including a healthy homolog
  deployment and verified storage persistence/backup.
- [ ] Run focused specs and CI after the remaining NARUTO-03 implementation.

Discount/total-adjustment and model-55 field analysis move to
[NARUTO-07](../naruto-07/01-product-and-data-contract.md). Printed-text and screenshot
OCR move to [NARUTO-08](../naruto-08/01-product-and-data-contract.md). Additional state
adapters need a separate scope choice; do not imply nationwide support.

## Security and privacy constraints

- Parse uploaded XML locally with a hardened XML parser configuration: disable external
  entities/DTD expansion and enforce byte, node, and processing limits. Bound PDF/image
  decoding by file size, page count, pixel count, processing time, and output length;
  reject active PDF content and unsafe file formats. NARUTO-08 defines OCR limits.
- A QR URL is untrusted input. Permit HTTPS only, use an explicit host/state allowlist,
  reject private, loopback, link-local, and metadata IP destinations, and revalidate
  every redirect/DNS resolution. Apply strict connection/read timeouts and response
  size limits. Never build a generic server-side URL fetcher.
- Keep source content and extracted financial data within the application by default.
  Official SEFAZ consultation necessarily sends a document identifier to that service;
  disclose the lookup in the UI. Do not send receipt images, XML, QR URLs, issuer, or
  recipient data to a third-party AI/OCR service without a separate privacy review
  and explicit product decision.
- Require an authenticated user and validate that the resulting transaction remains
  in that user's selected context and ownership scope.
- Do not log raw XML, full QR URLs, access keys, or personal taxpayer identifiers.

## Implementation slices

Development on `naruto-03-v2` has implemented the first vertical slice: authorized XML,
Goiás signed-QR lookup, Paraná key/QR lookup, PDF text extraction, image/camera QR
scanning, and cash/card draft prefill. The import modal is launched from index pages;
it includes state choice, a non-overflowing custom file picker with filename display,
disabled-until-selected Import file action, and bulk category/entity defaults. The
user reports the supported flows manually tested. This plan remains incomplete for
duplicate protection and the V2 attachment release gates; NF-e/reconciliation and
OCR are separate NARUTO-07 and NARUTO-08 features.

On desktop and PWA, the index-page import entry is a localized menu for importing now
or opening saved receipts; the ordinary New Transaction action remains separate. The
saved-receipt inbox uses the standard full-width index layout with responsive entries.
Imported items open the regular cash/card Split Purchase form, whose mobile line-item
spacing and balance summary are adapted for narrow screens without changing the desktop
form behavior.

The saved receipt inbox has an initial implementation: phone imports can be saved
without creating a financial transaction, and a user-owned inbox can reopen them in
cash or card forms on another device. The user reports this flow manually exercised;
follow-up security hardening remains open below. The inbox does not replace or auto-save normal
cash/card transactions.

### Slice 0 — Persisted receipt inbox and cross-device handoff

Implemented on `naruto-03-v2`: persistence, localized save-for-later action, desktop
and PWA inbox entry points, cash/card prefill, source transfer on successful save, and
retention after validation failure have focused model/request/feature coverage.

- Verify the implemented owner-scoped `FiscalReceiptDraft` persists normalized data
  independently from financial transactions and stores its source as a private Active
  Storage attachment.
- Verify the localized “Save for later” action, responsive inbox entry points, and
  multi-item desktop/mobile list. Keep immediate “Continue” behavior.
- Verify opening an item prefills the ordinary cash/card form. On successful normal
  submission, transfer the source artifact and consume the inbox item atomically; on
  validation failure, retain the item for retry.
- Maintain authenticated owner checks, safe deletion, and specs proving inbox items do
  not appear in transaction totals, installments, or reports.
- Manual regression: import several receipts on mobile, close/reopen the browser or
  switch devices, review each on desktop, save as cash/card transactions, and confirm
  each final transaction retains its source or generated evidence, as applicable.

### Slice 1 — Supported-source discovery and fixtures

Partially complete: the first GO and PR source paths have been investigated and
implemented, and the support limitations are documented above. Still needed are
sanitized fixtures and broader failure cases for reliable repeatable coverage.

- Build a support matrix for XML, PDF/image QR extraction, and manual 44-digit key by
  fiscal model, QR version, state, and consultation endpoint. Verify
  which official responses contain product rows and whether automation is permitted.
- Gather sanitized, non-personal fixtures for successful, malformed, and unsupported
  receipts, including a photographed QR and a key-only
  case. Do not use live taxpayer documents in automated tests.
- Lock the parser output schema and duplicate identifier. NARUTO-07 analyzes fiscal
  adjustments and fuller reconciliation behavior.

### Slice 2 — Safe parsing and retrieval

The initial XML, QR/key, PDF, and image source adapters plus state-specific lookup
services exist. Remaining verification should cover hostile/malformed input, response
limits, and lookup failures before treating retrieval as release-hardened.

- Verify each adapter returns the normalized draft shape with source provenance and
  safe errors; add missing malformed/unsupported-source cases to service specs.
- Verify QR retrieval against the documented host allowlist, redirects, response-size
  limits, timeouts, and any rate limits. Treat CAPTCHA, missing items, and unsupported
  states as normal fallback outcomes, not parser successes.
- Confirm extraction errors do not persist partial or untrusted data as financial
  records. Keep remote lookup out of request-critical paths if latency requires it.

### Slice 3 — Transaction form prefill

Implemented: the entry point is an import modal on the cash/card index pages; results
prefill the ordinary transaction form without saving. The user can apply category and
entity defaults to all line items, then change exceptions. The user reports the cash
and card flow manually tested.

- Acceptance check: existing selectors, repayment modal, price masking, line-item
  add/remove, attachment handling, and validation feedback still work after prefill.
- Acceptance check: unmatched totals remain visible and the existing exact-sum contract
  prevents an invalid transaction from being saved.

### Slice 4 — Duplicate protection and persistence policy

Partially complete: imported uploaded source files, generated key/QR-only manifests,
and Goiás consultation snapshots are staged as receipt attachments, including through
the saved receipt inbox. Duplicate policy and protection are still undecided/unimplemented.

- Define whether fiscal identifiers are stored on the transaction or an import record.
- Prevent accidental duplicate imports within the agreed user/context scope, while
  allowing an explicit intentional duplicate if the product decision permits it.
- Never log remote response bodies. Retain the user's source or a local JSON manifest;
  for Goiás, retain only the verified public DANFE/detail pages and derived JSON as
  private, forced-download evidence. Do not mislabel derived JSON as signed XML.

### Slice 5 — Verification and rollout

Still open here: duplicate protection and attachment/security edge cases. Manual
end-to-end testing is reported complete; OCR and richer total adjustment behavior
are tracked in NARUTO-08 and NARUTO-07 respectively.

- Unit specs for sanitized XML, QR/key, PDF/image, and current cent-precision conversion.
- Service/request specs for key format/check digit, QR allowlist, malformed URLs,
  redirect attempts, private destinations, timeouts, oversized responses/files,
  unsupported state formats, CAPTCHA/missing-item fallbacks, and duplicate documents.
- Form/request coverage for cash and card draft prefill, optional/blank categories,
  bulk defaults and overrides, edited items, total mismatch, user cancellation, and
  successful normal submission.
- Retain the user-completed manual source checks as a regression script for future changes.
- Run focused specs, RuboCop, and `bin/ci`; release only after attachment V2 storage
  and security gates are also satisfied.

## Open decisions before implementation

1. What duplicate policy should apply when the same fiscal identifier is imported
   again in the same or another context?
2. Which additional state formats should be prioritized after GO and PR, based on
   official item-bearing consultation paths and feasibility without CAPTCHA or
   restricted credentials? This is optional expansion, not a NARUTO-03 closure gate.

OCR coverage and review belong to [NARUTO-08](../naruto-08/01-product-and-data-contract.md).
Document adjustments and NF-e field accuracy belong to
[NARUTO-07](../naruto-07/01-product-and-data-contract.md).

## Explicitly out of scope

- Screenshot/document OCR, including faded printed cupoms (NARUTO-08).
- Model-55 NF-e hardening and expanded fiscal adjustment handling (NARUTO-07).
- Bank-statement PDF parsing or automatic bank matching.
- Automatic category/entity inference without an explicit user-confirmed rule.
- Automatic transaction creation or silent submission.
- Tax/accounting advice or recalculation of fiscal tax liability.
