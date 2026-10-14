# NARUTO-03 V3 — Brazilian cupom fiscal to transaction line items

## Status and ownership

**Planned; not implemented. Required for NARUTO-03 to be considered complete.** This
workstream is distinct from V2 attachment security and deployment hardening. Fiscal
data is translated into a draft using NARUTO-02's existing `LineItem` form and model;
it does not change the ownership of composite-transaction behavior from NARUTO-02.
The `naruto-03-v2` development branch is intended to implement this workstream. The
V3 label names the existing document/feature slice, not a required branch name.

## Goal

Let a user start a cash or card transaction from an attached Brazilian cupom fiscal
or its 44-digit access key and prefill the transaction with its item descriptions and
amounts. The user reviews and completes the draft—including categories, entities,
payment instrument, and any unresolved total difference—before saving. Import must
never silently create a financial transaction.

## Inputs and retrieval contract

The intended entry point accepts an uploaded receipt (XML, PDF, or a supported image),
a pasted QR-code URL, or a manually entered **44-digit fiscal access key**. An image
or PDF may contain a QR code, printed key, and/or readable item text. The existing
10 MiB per-file attachment limit applies to uploads; ZIP remains an attachment type,
but importing its contents is not promised by this plan. Camera capture may be added
as another way to supply an image, without becoming a prerequisite for file upload.

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

The initial discovery gives this support matrix. It is evidence about the official
interfaces, **not** a claim that an importer already works:

| Input/path | Official evidence | Initial development decision |
|---|---|---|
| NFC-e/NF-e XML supplied by the user | Structured fiscal item and total fields are defined by the official XML schemas. | Parse locally first; require an authorized document and validate the fiscal key/total. |
| NFC-e QR URL, including QR 3.0 | PR publishes a QR consultation URL and the QR 3.0 parameter layout. The public result is a state page, not a documented universal item API. | Pilot only a verified state/QR format; confirm live item rows before adding an adapter. |
| NFC-e 44-digit key without a QR URL | NFC-e public consultation supports key entry, but PR's complete consultation has CAPTCHA. | Accept and validate the key; only promise automatic items for a verified no-CAPTCHA state path. Otherwise explain the limitation and offer receipt upload. |
| NF-e 44-digit key through `NFeDistribuicaoDFe` | The service requires an eligible interested party and certificate; key possession alone is insufficient. | Do not use it for ordinary consumer import. |
| Printed fiscal image/PDF | No state lookup is guaranteed from the short receipt number or illegible QR. | Extract local text/QR where feasible, require review of uncertain rows, and keep manual entry available. |

Unsupported or inaccessible documents must show a useful explanation and preserve
the user's ability to enter line items manually.

Official starting points: [NFC-e public consultation manual](https://www.nfe.fazenda.gov.br/portal/exibirArquivo.aspx?conteudo=DdSDvm4LtCI%3D),
[PR consultation example with CAPTCHA](https://sped.fazenda.pr.gov.br/NFCe/webservices/sped/nfce/completa),
[PR QR 3.0 layout](https://sped.fazenda.pr.gov.br/NFCe/Pagina/QR-Code),
and [NF-e distribution service specification](https://www.nfe.fazenda.gov.br/Portal/exibirArquivo.aspx?conteudo=U0LlsYVGBRU%3D).

## Draft data contract

Extract only values needed to create and review the draft:

- issuer name, fiscal document model/state, and identifier/access key, when present;
- issue date/time and document total;
- one draft line item per fiscal product/service row, with source description,
  quantity/unit details where available, and a cent-precision line amount;
- document-level discounts, freight, or other totals that explain a difference between
  item amounts and the printed total.

The importer may suggest the transaction description, date, and total. It must not
guess categories or entities in the first version. Each line item still needs a valid
NARUTO-02 category before save, subject to its existing entity/category rules. Entity
allocation and cash friend-repayment details remain user-controlled. Keep source row
order and show extraction confidence or an explicit review flag for OCR-derived rows.

The imported item amounts should be reconciled against the fiscal total and the
transaction's integer-cent total. Do not silently alter a product price to force a
match. If document-level adjustments cannot be allocated unambiguously, preserve the
item amounts, show the difference, and require the user to resolve it in the existing
split-purchase form before submission.

## User flow

1. From a new transaction form, choose fiscal import and upload a receipt, paste a QR
   URL, or enter a 44-digit access key.
2. Validate and parse the source; show an explicit loading/progress and error state.
3. Populate an unsaved cash/card transaction draft: date/description/total where
   available, plus editable line-item descriptions and prices.
4. Show source identity and any total mismatch. Allow the user to edit rows, add or
   remove rows, assign categories and entities, and choose the payment instrument.
5. Save only through the normal transaction form after existing NARUTO-02 validations
   pass. Let the user retain the uploaded source as a receipt attachment; a key or QR
   URL alone must not be represented as an attached file. Do not attach an uploaded
   file twice if it was already staged in the form.
6. Detect an already-imported document identifier for the current user/context and
   warn before creating a duplicate. The exact duplicate policy is an open decision.

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

### Slice 1 — Supported-source discovery and fixtures

- Build a support matrix for XML, PDF/image QR extraction, manual 44-digit key, and
  OCR fallback by fiscal model, QR version, state, and consultation endpoint. Verify
  which official responses contain product rows and whether automation is permitted.
- Gather sanitized, non-personal fixtures for successful, malformed, unsupported, and
  adjustment-heavy receipts, including photographed/printed receipts and a key-only
  case. Do not use live taxpayer documents in automated tests.
- Lock the parser output schema, duplicate identifier, and behavior when the total
  cannot be reconciled.

### Slice 2 — Safe parsing and retrieval

- Add dedicated XML, QR/key, and PDF/image extraction services that return one
  normalized draft result with source provenance and review flags.
- Isolate supported official lookups behind an allowlisted retrieval service with
  SSRF, redirect, response-size, rate-limit, and timeout protections. Keep it out of
  controllers. Treat CAPTCHA, missing items, and unsupported states as normal
  fallback outcomes, not parser successes.
- Run slower remote lookups through Solid Queue; parsing an uploaded small XML may be
  synchronous if bounded and measured.
- Store extraction errors as safe user-facing messages; do not persist partial or
  untrusted parsed records as financial data.

### Slice 3 — Transaction form prefill

- Add an import entry point to cash/card transaction creation, including an attachment
  picker and 44-digit key field.
- Map parser output into the existing NARUTO-02 line-item builder without saving.
- Preserve normal category/entity selectors, repayment modal behavior, price masking,
  line-item add/remove, attachment handling, and validation feedback.
- Make unmatched totals visible and block save until the existing exact-sum contract is
  satisfied.

### Slice 4 — Duplicate protection and persistence policy

- Define whether fiscal identifiers are stored on the transaction or an import record.
- Prevent accidental duplicate imports within the agreed user/context scope, while
  allowing an explicit intentional duplicate if the product decision permits it.
- Decide whether an uploaded source is retained as a receipt attachment by default or
  only on user request. Avoid storing a remote response if the source is not retained.

### Slice 5 — Verification and rollout

- Unit specs for sanitized XML, QR/key, PDF/image, OCR review flags, and monetary
  conversion/reconciliation.
- Service/request specs for key format/check digit, QR allowlist, malformed URLs,
  redirect attempts, private destinations, timeouts, oversized responses/files,
  unsupported state formats, CAPTCHA/missing-item fallbacks, and duplicate documents.
- Form/request coverage for cash and card draft prefill, category completion, edited
  items, total mismatch, user cancellation, and successful normal submission.
- Manual test with a redacted receipt for each supported format/state.
- Run focused specs, RuboCop, and `bin/ci`; release only after attachment V2 storage
  and security gates are also satisfied.

## Open decisions before implementation

1. Which state/issuer formats and official consultation endpoints can return item rows
   for an uploaded QR code or manually entered access key without CAPTCHA or restricted
   credentials? Publish the first supported matrix before promising key-only import.
2. Which local PDF/image extraction and OCR method meets quality, privacy, and resource
   limits? How will the UI flag uncertain descriptions and prices for review?
3. Should an uploaded source be attached automatically, offered as an opt-in, or
   retained only when the user explicitly chooses it?
4. Should document-level adjustments create an explicit draft line item, or should the
   user resolve the difference manually? Default safety behavior in this plan is to
   leave a visible mismatch and require user resolution.
5. What duplicate policy should apply when the same fiscal identifier is imported
   again in the same or another context?

## Explicitly out of scope

- General OCR of arbitrary non-fiscal receipts or handwritten documents. OCR of a
  supported printed cupom fiscal is part of this plan when structured lookup fails.
- Bank-statement PDF parsing or automatic bank matching.
- Automatic category/entity inference without an explicit user-confirmed rule.
- Automatic transaction creation or silent submission.
- Tax/accounting advice or recalculation of fiscal tax liability.
