# NARUTO-03 V3 — Brazilian cupom fiscal to transaction line items

## Status and ownership

**Planned; not implemented. Required for NARUTO-03 to be considered complete.** This
workstream is distinct from V2 attachment security and deployment hardening. Fiscal
data is translated into a draft using NARUTO-02's existing `LineItem` form and model;
it does not change the ownership of composite-transaction behavior from NARUTO-02.

## Goal

Let a user start a cash or card transaction from a Brazilian cupom fiscal and prefill
the transaction with its item descriptions and amounts. The user reviews and completes
the draft—including categories, entities, payment instrument, and any unresolved total
difference—before saving. Import must never silently create a financial transaction.

## Proposed first supported inputs

The exact input interaction is still a product decision. The initial implementation
should evaluate these structured sources:

1. Upload an NFC-e/NF-e XML file.
2. Paste or scan the QR-code URL printed on a cupom fiscal, then retrieve the public
   fiscal document only when its host and request shape are explicitly allowed.

Do not assume that every Brazilian state uses an identical QR format or exposes the
same public response. The discovery slice must establish the first supported document
types, state/issuer coverage, and graceful behavior for unsupported receipts before
the parser contract is locked. Camera scanning is an optional input method, not a
prerequisite to accept a pasted URL or uploaded XML.

## Draft data contract

Extract only values needed to create and review the draft:

- issuer name and fiscal document identifier/access key, when present;
- issue date/time and document total;
- one draft line item per fiscal product/service row, with source description,
  quantity/unit details where available, and a cent-precision line amount;
- document-level discounts, freight, or other totals that explain a difference between
  item amounts and the printed total.

The importer may suggest the transaction description, date, and total. It must not
guess categories or entities in the first version. Each line item still needs a valid
NARUTO-02 category before save. Entity allocation and cash friend-repayment details
remain user-controlled.

The imported item amounts should be reconciled against the fiscal total and the
transaction's integer-cent total. Do not silently alter a product price to force a
match. If document-level adjustments cannot be allocated unambiguously, preserve the
item amounts, show the difference, and require the user to resolve it in the existing
split-purchase form before submission.

## User flow

1. From a new transaction form, choose fiscal import and provide one supported source.
2. Validate and parse the source; show an explicit loading/progress and error state.
3. Populate an unsaved cash/card transaction draft: date/description/total where
   available, plus editable line-item descriptions and prices.
4. Show source identity and any total mismatch. Allow the user to edit rows, add or
   remove rows, assign categories and entities, and choose the payment instrument.
5. Save only through the normal transaction form after existing NARUTO-02 validations
   pass. Optionally retain the uploaded XML as a receipt attachment; a QR URL alone
   must not be represented as an attached file.
6. Detect an already-imported document identifier for the current user/context and
   warn before creating a duplicate. The exact duplicate policy is an open decision.

## Security and privacy constraints

- Parse uploaded XML locally with a hardened XML parser configuration: disable external
  entities/DTD expansion and enforce byte, node, and processing limits.
- A QR URL is untrusted input. Permit HTTPS only, use an explicit host/state allowlist,
  reject private, loopback, link-local, and metadata IP destinations, and revalidate
  every redirect/DNS resolution. Apply strict connection/read timeouts and response
  size limits. Never build a generic server-side URL fetcher.
- Keep source content and extracted financial data within the application by default.
  Do not send XML, QR URLs, issuer, or recipient data to a third-party AI/OCR service
  without a separate privacy review and explicit product decision.
- Require an authenticated user and validate that the resulting transaction remains
  in that user's selected context and ownership scope.
- Do not log raw XML, full QR URLs, access keys, or personal taxpayer identifiers.

## Implementation slices

### Slice 1 — Supported-source discovery and fixtures

- Select the first fiscal standards/QR formats and states to support.
- Gather sanitized, non-personal fixtures for successful, malformed, unsupported, and
  adjustment-heavy receipts. Do not use live taxpayer documents in automated tests.
- Lock the parser output schema, duplicate identifier, and behavior when the total
  cannot be reconciled.

### Slice 2 — Safe parsing and retrieval

- Add a dedicated parser service for uploaded XML.
- If QR retrieval is included, isolate it behind an allowlisted retrieval service with
  SSRF, redirect, response-size, and timeout protections. Keep it out of controllers.
- Run slower remote lookups through Solid Queue; parsing an uploaded small XML may be
  synchronous if bounded and measured.
- Store extraction errors as safe user-facing messages; do not persist partial or
  untrusted parsed records as financial data.

### Slice 3 — Transaction form prefill

- Add an import entry point to cash/card transaction creation.
- Map parser output into the existing NARUTO-02 line-item builder without saving.
- Preserve normal category/entity selectors, repayment modal behavior, price masking,
  line-item add/remove, attachment handling, and validation feedback.
- Make unmatched totals visible and block save until the existing exact-sum contract is
  satisfied.

### Slice 4 — Duplicate protection and persistence policy

- Define whether fiscal identifiers are stored on the transaction or an import record.
- Prevent accidental duplicate imports within the agreed user/context scope, while
  allowing an explicit intentional duplicate if the product decision permits it.
- Decide whether the source XML is retained as a receipt attachment by default or only
  on user request. Avoid storing a remote response if the source is not retained.

### Slice 5 — Verification and rollout

- Unit specs for sanitized XML fixtures and monetary conversion/reconciliation.
- Service/request specs for QR allowlist, malformed URLs, redirect attempts, private
  destinations, timeouts, oversized responses/files, unsupported state formats, and
  duplicate documents.
- Form/request coverage for cash and card draft prefill, category completion, edited
  items, total mismatch, user cancellation, and successful normal submission.
- Manual test with a redacted receipt for each supported format/state.
- Run focused specs, RuboCop, and `bin/ci`; release only after attachment V2 storage
  and security gates are also satisfied.

## Open decisions before implementation

1. First supported fiscal sources: XML upload only, pasted QR URL, camera QR scan, or a
   staged combination? Recommended first release: XML upload plus pasted QR URL; add
   camera scanning only if the device/browser UX justifies it.
2. Which state/issuer formats are in scope for the first supported cupom QR lookup?
3. Should the source XML be attached automatically, offered as an opt-in, or retained
   only when the user explicitly uploads it?
4. Should document-level adjustments create an explicit draft line item, or should the
   user resolve the difference manually? Default safety behavior in this plan is to
   leave a visible mismatch and require user resolution.
5. What duplicate policy should apply when the same fiscal identifier is imported
   again in the same or another context?

## Explicitly out of scope

- General OCR of arbitrary receipt photos or handwritten documents.
- Bank-statement PDF parsing or automatic bank matching.
- Automatic category/entity inference without an explicit user-confirmed rule.
- Automatic transaction creation or silent submission.
- Tax/accounting advice or recalculation of fiscal tax liability.
