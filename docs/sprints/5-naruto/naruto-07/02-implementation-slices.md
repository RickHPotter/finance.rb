# NARUTO-07 — Implementation slices and acceptance matrix

## Status

The main implementation slices are in place. The [contract](01-product-and-data-contract.md)
records product decisions and limitations; the [field inventory](03-field-inventory-and-reconciliation.md)
records current source behavior. Real-source verification and manual acceptance remain open.

## Slice 0 — Examples, source capabilities, and decisions

Status: initial source inventory and synthetic examples prepared. Real sanitized
model-55 and GO adjustment examples, current schema/status confirmation, and final
source-specific reconciliation semantics remain verification work in later slices;
the synthetic fragments are not proof of real-world source compatibility.

- Collect sanitized model-55 authorized XML examples: ordinary, discount, freight or
  other charges, and an adjustment-heavy or inconsistent case. Obtain permission to
  use real documents only as input for sanitization; do not commit taxpayer details,
  real access keys, live QR URLs, or production artifacts. If examples are unavailable,
  use clearly labeled synthetic examples and document what remains unverified.
- Add a sanitized Goiás model-65 consultation example with R$119.95 product value,
  R$10.00 discount, and R$109.95 payable; retain a comparable XML example if available.
- Map the exact XML and supported GO/PR consultation fields to draft output and
  identify unavailable or ambiguous data. Distinguish original item values, item
  adjustments, document totals, tax information, and the payment actually recorded.
- Specify the user's dedicated discount line, its reserved DISCOUNT category, absence
  of entity, first-place ordering, manual Add Discount action, and automatic import.
  Verify the chosen separate DISCOUNT reporting behavior, investigate insurance and
  other adjustments, and decide how user edits affect provenance.
- Check model-55 status/protocol and key consistency requirements against official
  sources; record what can and cannot be inferred from a supplied document alone.

Done when the field matrix, examples, and decisions are reviewable, including how
each alternative affects existing line-item sign and exact-sum validations. Do not
invent source fields or silently compensate for an unexplained difference.

## Slice 1 — Fiscal document parsing and evidence

Status: preliminary parser work captures separate source amounts and checks a supplied
protocol key for model 55 (and rejects a mismatched key for model 65 when supplied).
Normalized XML item amounts now preserve gross product values; recognized discounts
and freight are separate, with source amounts retained in the saved receipt. Synthetic
fixtures do not establish full schema, signature, cancellation, or real-world document
support. Slice 1 remains open for source verification.

- Extend the bounded XML parser for model 55 and preserve existing model-65 support.
  Validate supported structure, access key and model, and protocol consistency as
  established in slice 0; distinguish supplied authorization evidence from current
  status and cryptographic signature verification.
- Capture original product values and separately identify supported item/document
  adjustments, document totals, and provenance. Use decimal-safe parsing, integer
  cents for currency totals, and sufficient precision for quantity and unit price.
- Keep raw input and evidence under the existing attachment limits and authorization.
  Reject malformed/oversized inputs; never fetch arbitrary source URLs.

Acceptance: supported sanitized model-55 fixtures parse correctly; malformed keys,
model/key/protocol mismatches and unsupported states are handled visibly. Model-65
regressions pass. Tests do not imply cancellation or signature verification unless
the implementation actually provides it.

## Slice 2 — Reconciliation and review

Status: discount identity, reserved category migration, manual form control, XML/GO
discount and freight integration, original-source review, and category reporting are
implemented. Synthetic GO markup does not prove live source support. Paraná discount
and freight extraction is not established: unexplained differences remain visible for
manual resolution rather than being guessed.

- Add the permanent DISCOUNT system category and a dedicated discount line type or
  equivalent server-validated identity. Only the Add Discount action and fiscal import
  may create it; prohibit ordinary category selection and prevent category/entity
  tampering. The line remains removable; enforce at most one per transaction.
- Add the Add Discount control and automatically insert known fiscal discounts. Keep
  discount lines first after add, import, edits, save/reopen, duplication, and removal.
  Preserve the product values and distinguish original fiscal evidence from user edits.
- Report product amounts under their original categories and the discount separately
  under DISCOUNT, with a reducing effect on net expense. Cover category, entity, and
  total reports without presenting the discount as ordinary income.
- Present source-identified freight as a separate charge line, preserving the product
  prices and the final payable amount. Let users review its categorization; leave
  unsupported charges or unexplained residuals visible for manual resolution.
- Implement the chosen adjustment representation through normalized draft, saved
  inbox payload, and cash/card forms. Preserve source values and clearly distinguish
  source-derived adjustments from user corrections.
- Show the product sum, recognized adjustments, document total, selected transaction
  amount, and unexplained difference. Document handling of discounts already reflected
  in item values so they are never counted twice.
- Address the existing line-item sign and exact-sum rules, allocations, reports,
  duplication, audit/rollback, and edits in the chosen design. Never automatically
  create an unexplained balancing entry.
- Preserve old saved draft payloads and existing receipt/evidence handoff. On a failed
  transaction save, the saved draft and evidence remain available.

Acceptance: the Goiás example explains the R$10.00 discount and reconciles to
R$109.95 without silently rewriting the original R$119.95 products; its first line is
the removable discount, with the fixed DISCOUNT category and no entity. Unexplained
differences are visible and prevent a misleading save until resolved.

## Slice 3 — Duplicate protection

Status: signed identities and scoped links support import warnings, final-save checks,
explicit repeats, and user-wide saved-draft warnings. The final check serializes saves
on the user's database row. New links and split items are preserved when cloning a
context. Existing transactions and unsigned legacy drafts have no trusted identity and
are not backfilled from arbitrary attachments; they remain usable but cannot reliably
participate in duplicate warnings. Deleting a linked transaction or signed draft removes
its match. Audit rollback currently recreates a deleted transaction without its fiscal
link, so that restored transaction will not itself trigger a duplicate warning. Restoring
the identity through audit history needs a design that respects access-key handling.

- Persist a validated fiscal identity for draft and completed transaction paths; a
  blob filename or client-submitted draft field alone is not a trusted identity.
  Design an atomic server-side final check for concurrent submissions.
- Apply current-context completed-transaction warnings and explicit repeat confirmation
  to immediate imports and cash/card saves; prevent cross-user disclosure. For existing
  user-owned saved receipts, warn and offer opening the existing receipt or explicitly
  saving another. Deleted records do not trigger warnings; existing saved receipts count
  until deleted or consumed. Cover failed saves and reopening the same draft.
- Keep old transactions without fiscal identity usable; define any backfill separately
  and do not infer a reliable key from arbitrary attachments.

Acceptance: tests cover both transaction types, drafts and completed records, other
users and contexts, repeat lookup without save, retries, deletion, simultaneous
submissions, and any explicit override. No duplicate check leaks another user's data.

## Slice 4 — End-to-end verification and handoff

Focused checks so far cover the fiscal parser and requests, discount forms in a browser,
category reports, and context clone/purge. A full CI run is in progress; record its final
result separately rather than treating these focused checks as full acceptance.

For manual testing, use documents the user is authorized to inspect. Check an ordinary
receipt, a discount and freight, and an unexplained mismatch in both cash and card
forms. Verify the original amounts, editable rows, fixed discount category, evidence,
duplicate warning and explicit repeat, saved-receipt reopening, and category totals.
Repeat the key flows on mobile and desktop. Keep real keys, personal details, and live
QR URLs out of committed fixtures and documentation.

- Run focused parser, draft, model, request, rollback/reporting, and browser specs;
  test saved-inbox transfer and validation failure; build JavaScript and run RuboCop.
- Run `bin/ci` after the final implementation. Record failures accurately and avoid
  claiming full CI or manual acceptance based on focused checks alone.
- Manually test supported XML and GO/PR examples, a discount and a charge, a visible
  mismatch, duplicate handling, saved draft reopening, and cash/card final saves on
  desktop and mobile. Verify preserved source evidence and relevant report totals.
- Record results and remaining source limitations in the contract and `SPRINT_5.md`.

Additional NF-e retrieval, DANFE text extraction, and OCR require separate feasibility
and scope decisions; a 44-digit key alone is not a promise of product data retrieval.
