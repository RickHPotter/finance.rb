# NARUTO-08 — OCR-assisted transaction entry

## Purpose and boundary

This is a separate, planned feature for creating reviewable transaction drafts from
screenshots and photographed documents. It is deliberately the last NARUTO feature;
NARUTO-03 handles structured NFC-e/cupom sources and NARUTO-07 handles NF-e model 55
and monetary-field accuracy. OCR must help when structured data is missing, not
replace a verified XML/QR result with a less reliable guess.

Initial document families to investigate: transaction or purchase screenshots,
printed fiscal cupoms, NF-e and NFC-e DANFE images/PDFs, and orçamentos. An orçamento
is an estimate, not proof of payment; it may prefill a draft but must not be labelled
as an issued fiscal document or automatically saved as a completed transaction.

## Product contract to design

- Import produces an **unsaved**, editable cash/card draft through the existing form.
  The user confirms date, merchant/description, total, categories, entities, and each
  line item before normal validation and save. OCR output is never authoritative.
- Show source provenance and uncertainty at field/row level. Missing or conflicting
  prices, dates, quantities, and totals require visible review; no invisible balancing
  or fabricated line items.
- For a photographed cupom, try an available QR/structured route and OCR as
  complementary paths. Faded ink may make printed text unreadable while the QR works;
  a damaged QR may leave text legible. Compare results when both work and flag
  disagreements rather than silently preferring one.
- Reuse NARUTO-07's field inventory and reconciliation rules for fiscal adjustments.
  For non-fiscal screenshots and estimates, distinguish visible amount, inferred
  amount, and user-entered correction.
- Keep private source attachments under the existing size/count, ownership, and
  download rules. Do not send images or personal data to a third-party OCR/AI service
  without an explicit privacy and product decision.

## Development slices

1. **Discovery and fixtures:** identify the first screenshot/document layouts to
   support; collect sanitized clear, blurry, cropped, and faded examples, including
   cupoms with readable QR only, readable text only, both, and neither.
2. **Bounded extraction:** select a privacy-preserving OCR approach and enforce image
   dimensions, PDF pages, file bytes, processing time, and output limits. Record
   extraction confidence and handle unsupported files safely.
3. **Structured-source pairing:** run existing XML/QR lookup when present, compare its
   fields with OCR results, and present a source-aware review instead of overwriting
   verified data. A failed QR or lookup should not prevent OCR review.
4. **Draft review UI:** map candidate fields and line items into the ordinary cash/card
   form, highlight uncertain/conflicting values, and require the user to resolve
   monetary differences before saving.
5. **Verification:** test clear and faded cupoms, broken QR, screenshots, NF-e/NFC-e
   images, estimates, missing values, conflicting totals, privacy constraints, and
   cash/card save behavior. Validate manually on mobile and desktop, then run CI.

## Open decisions

- Which local OCR engine and language packs meet the app's quality, deployment-size,
  latency, and privacy constraints? A remote service is a separate opt-in decision.
- What confidence threshold should trigger a mandatory review marker, and how should
  corrected values be retained without storing unnecessary OCR text?
- Which screenshot layouts are in the first release? Do not promise arbitrary app
  screenshots or handwritten notes until examples and tests support them.

Completion requires a documented source matrix, safe extraction, visible uncertainty
and reconciliation, regression coverage, and manual validation. NARUTO-03 is already
closed; NARUTO-08 completion does not imply NARUTO-07 completion.
