# NARUTO-03 V3 — Brazilian cupom fiscal to transaction line items

## Status and ownership

**First supported-source slice implemented; manual validation and planned fallbacks
remain.** Authorized XML prefill, Goiás NFC-e signed-QR lookup, Paraná NFC-e key/QR
lookup, PDF text-source extraction, and image/camera QR scanning are implemented.
The cash/card index pages launch the import modal. It defaults to Goiás, lets the user
select Paraná, and provides bulk category/entity defaults with per-line-item edits.
The file picker shows its selected filename and keeps Import file disabled until a
file is selected. OCR for receipts without a usable structured source,
duplicate-document protection, and agreed state expansion remain open. This workstream
is distinct from V2 attachment security and deployment hardening. Fiscal data is
translated into an unsaved draft using NARUTO-02's existing `LineItem` form and model;
it does not change the ownership of composite-transaction behavior from NARUTO-02.
The V3 label names the existing document/feature slice, not a required branch name.

## New requirement — saved receipt inbox

The current import result lives in browser `sessionStorage` until the user submits a
cash/card form. That is not enough for the intended phone-to-PC workflow. Add a
server-persisted **receipt inbox**: a user can import a cupom on mobile, save it for
later, collect multiple receipts, then open each on desktop, choose cash or card,
review/edit the prefilled transaction, and submit it normally. Saving an inbox item
must not create a financial transaction or affect balances, installments, or reports.

Treat inbox items as fiscal-receipt drafts, not incomplete `CashTransaction` or
`CardTransaction` rows. This avoids weakening normal transaction validations or
letting incomplete records leak into financial queries. Each saved item stores the
normalized import payload, owner, creation time, and original source attachment where
available. Persist the exact uploaded XML/PDF/photo (including a camera-captured QR
image); when the user supplied only a key/URL, preserve a small JSON source manifest
with the identifier and parsed draft instead of retaining remote SEFAZ HTML. Keep the
source file under the existing 10 MiB / attachment-count / MIME security contract.

On final transaction save, attach the saved source artifact to the resulting cash/card
transaction and consume the inbox item atomically. Explicit deletion removes the saved
item and its source attachment. Enforce owner/context access on list, read, consume,
and delete operations; never expose a public blob URL. A user can save multiple items
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
a QR code and is not OCR/photo text recognition. Successful file imports stage the
original upload as a receipt attachment; key/URL-only lookup has no file to attach.

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
3. If lookup is unavailable, blocked, or omits items, extract text from the uploaded
   image/PDF with a bounded OCR/text-extraction path and present uncertain rows for
   review. Never invent missing items or infer their prices from the document total.

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
| Authorized NFC-e/NF-e XML | Parses supported structured fiscal item and total fields locally into a draft. | Requires valid authorized XML; unsupported/malformed documents return a user-facing error. |
| Goiás NFC-e signed QR URL | Looks up item rows through the official consultation when given the complete signed URL. | A bare GO key cannot be used because the public key-entry page has a browser challenge; provide the QR URL or XML. |
| Paraná NFC-e QR URL or 44-digit key | Extracts a PR key from the QR URL or accepts a validated 44-digit key, then retrieves item rows via the PR QR path. | State-specific; public consultation/layout changes can cause a safe lookup failure. |
| PDF text | Extracts a GO QR URL or Paraná key from selectable text in the first three pages. | Scanned/image-only PDFs and PDFs without a supported URL/key need OCR, which is not implemented. |
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

Extract only values needed to create and review the draft:

- issuer name, fiscal document model/state, and identifier/access key, when present;
- issue date/time and document total;
- one draft line item per fiscal product/service row, with source description,
  quantity/unit details where available, and a cent-precision line amount;
- document-level discounts, freight, or other totals that explain a difference between
  item amounts and the printed total.

The importer may suggest the transaction description, date, and total. It does not
guess categories or entities. The user can apply category/entity defaults to all
imported line items, then edit exceptions; categories may be left blank under the
current NARUTO-02 contract. Entity allocation and cash friend-repayment details remain
user-controlled. Keep source row order and show extraction confidence or an explicit
review flag for any future OCR-derived rows.

The imported item amounts should be reconciled against the fiscal total and the
transaction's integer-cent total. Do not silently alter a product price to force a
match. If document-level adjustments cannot be allocated unambiguously, preserve the
item amounts, show the difference, and require the user to resolve it in the existing
split-purchase form before submission.

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

The implemented paths are ready for manual development-environment testing. Start from
both `/cash_transactions` and `/card_transactions` index pages, open the import modal,
and use receipts you are entitled to view. Check every imported amount before saving:

1. Upload an authorized NFC-e/NF-e XML with at least one product and choose **Import
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
   uploaded file is staged in Attachments after a successful import; wait for its
   upload to finish before saving. A key-only lookup creates no attachment.
4. Assign categories, review any total difference, and save through the ordinary
   transaction form. Also try a one-product receipt and a receipt with a document
   discount; the former is valid with one LineItem, while the latter must display the
   difference for manual correction.

Current limits: Goiás NFC-e lookup needs the complete signed QR URL; Paraná currently
supports key-only lookup. XML parsing is local for supported authorized NF-e/NFC-e.
Image and camera import need a readable QR; PDF import needs selectable text containing
a supported GO QR URL or PR key in the first three pages. There is no OCR fallback for
printed item rows, scanned PDFs, or images without a QR. HEIC browser decoding depends
on support in the user's browser. Duplicate-document warnings and additional state
adapters remain pending. Lookup can fail if a state's public HTML changes or blocks the
query; manual line-item entry remains the fallback.

## Completion checklist

The first implementation is ready for manual testing, but the feature is not yet
verified end to end. Remaining gates are:

- [ ] Manually test cash and card imports for XML, GO QR, PR key/QR, PDF text, and
  image/camera QR; confirm one-item receipts, attachment retention, category/entity
  defaults with per-row overrides, and ordinary form save behavior.
- [ ] Verify discounts/other total adjustments and exact-sum behavior. The user must
  see and resolve any mismatch; the importer must not silently rewrite item prices.
- [ ] Decide and implement the planned printed-item OCR fallback, or explicitly defer
  it and narrow the product promise to receipts with XML or a supported readable QR/key.
- [ ] Decide the duplicate-document policy and implement a warning/protection scoped
  to the agreed user/context behavior.
- [ ] Finish V2 attachment security and durability gates in
  [the attachment plan](04-v2-development-plan.md), including a healthy homolog
  deployment and verified storage persistence/backup.
- [ ] Run focused specs and CI after remaining implementation; choose any additional
  state adapters separately rather than implying nationwide support.

## Security and privacy constraints

- Parse uploaded XML locally with a hardened XML parser configuration: disable external
  entities/DTD expansion and enforce byte, node, and processing limits. Bound PDF/image
  decoding and OCR by file size, page count, pixel count, processing time, and output
  length; reject active PDF content and unsafe file formats.
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
disabled-until-selected Import file action, and bulk category/entity defaults. This
plan remains incomplete pending manual validation, the agreed OCR/duplicate/reconciliation
work, and the V2 attachment release gates.

The saved receipt inbox is a newly agreed requirement and is not implemented. It is
the persistence layer for phone capture and later desktop transaction entry; it does
not replace or auto-save normal cash/card transactions.

### Slice 0 — Persisted receipt inbox and cross-device handoff

- Add an owner-scoped `FiscalReceiptDraft` (or equivalently named) record to persist
  normalized import data independently from financial transactions. Store its source
  using a private Active Storage attachment; use the uploaded XML/PDF/photo when
  present, and a generated JSON manifest for key/URL-only imports.
- Add a localized “Save for later” action after a successful import, plus a responsive
  inbox page/action that lists multiple pending receipts on desktop and mobile.
- Allow opening an inbox item into the ordinary cash/card new-transaction form. Keep
  existing immediate “Continue” behavior. On successful normal submission, attach the
  source artifact to the transaction and consume the inbox item; on validation failure,
  retain the item for retry.
- Add authenticated ownership/context checks, safe deletion, and tests proving inbox
  items do not appear in transaction totals, installments, audits, or reports.
- Acceptance check: import several receipts on mobile, close/reopen the browser or
  switch devices, review each on desktop, save as cash/card transactions, and confirm
  each final transaction retains its original source attachment.

### Slice 1 — Supported-source discovery and fixtures

Partially complete: the first GO and PR source paths have been investigated and
implemented, and the support limitations are documented above. Still needed are
sanitized fixtures and broader failure/adjustment cases for reliable repeatable coverage.

- Build a support matrix for XML, PDF/image QR extraction, manual 44-digit key, and
  OCR fallback by fiscal model, QR version, state, and consultation endpoint. Verify
  which official responses contain product rows and whether automation is permitted.
- Gather sanitized, non-personal fixtures for successful, malformed, unsupported, and
  adjustment-heavy receipts, including photographed/printed receipts and a key-only
  case. Do not use live taxpayer documents in automated tests.
- Lock the parser output schema, duplicate identifier, and behavior when the total
  cannot be reconciled.

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
entity defaults to all line items, then change exceptions. Manual tests still need to
confirm this flow end-to-end for both transaction types.

- Acceptance check: existing selectors, repayment modal, price masking, line-item
  add/remove, attachment handling, and validation feedback still work after prefill.
- Acceptance check: unmatched totals remain visible and the existing exact-sum contract
  prevents an invalid transaction from being saved.

### Slice 4 — Duplicate protection and persistence policy

Partially complete: imported uploaded source files are staged as transaction receipt
attachments; key/QR-only imports do not fabricate an attachment. Duplicate policy and
protection are still undecided/unimplemented.

- Define whether fiscal identifiers are stored on the transaction or an import record.
- Prevent accidental duplicate imports within the agreed user/context scope, while
  allowing an explicit intentional duplicate if the product decision permits it.
- Avoid retaining or logging remote response bodies; only the user's uploaded file is
  staged as an attachment.

### Slice 5 — Verification and rollout

Still open: manual end-to-end testing across both transaction types and each supported
source, OCR fallback policy/implementation, exact total-adjustment behavior, duplicate
protection, and security edge cases.

- Unit specs for sanitized XML, QR/key, PDF/image, OCR review flags, and monetary
  conversion/reconciliation.
- Service/request specs for key format/check digit, QR allowlist, malformed URLs,
  redirect attempts, private destinations, timeouts, oversized responses/files,
  unsupported state formats, CAPTCHA/missing-item fallbacks, and duplicate documents.
- Form/request coverage for cash and card draft prefill, optional/blank categories,
  bulk defaults and overrides, edited items, total mismatch, user cancellation, and
  successful normal submission.
- Manual test with a redacted receipt for each supported format/state.
- Run focused specs, RuboCop, and `bin/ci`; release only after attachment V2 storage
  and security gates are also satisfied.

## Open decisions before implementation

1. What exact coverage should OCR provide for printed cupom fiscal text when there is
   no readable QR or XML, and which local OCR method meets quality/privacy/resource
   limits? How should uncertain descriptions and prices be flagged?
2. Should document-level adjustments create an explicit draft line item, or should the
   user resolve the difference manually? Default safety behavior is to preserve the
   visible mismatch and require user resolution.
3. What duplicate policy should apply when the same fiscal identifier is imported
   again in the same or another context?
4. Which additional state formats should be prioritized after GO and PR, based on
   official item-bearing consultation paths and feasibility without CAPTCHA or
   restricted credentials?

## Explicitly out of scope

- General OCR of arbitrary non-fiscal receipts or handwritten documents. OCR of a
  supported printed cupom fiscal is part of this plan when structured lookup fails.
- Bank-statement PDF parsing or automatic bank matching.
- Automatic category/entity inference without an explicit user-confirmed rule.
- Automatic transaction creation or silent submission.
- Tax/accounting advice or recalculation of fiscal tax liability.
