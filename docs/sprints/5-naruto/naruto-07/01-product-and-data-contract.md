# NARUTO-07 — NF-e import and fiscal monetary accuracy

## Purpose and boundary

Harden NARUTO-03's basic XML parsing for NF-e (model 55), while investigating
the fiscal fields needed to represent purchases accurately. The current parser accepts
an authorized `nfeProc` whose model matches its access key, but its fixtures and
verified product behavior cover model 65; model-55 accuracy is not established.
NARUTO-03 still owns duplicate-document protection and
attachment release gates; NARUTO-08 owns OCR of screenshots and photographed documents.

The first NF-e source should be an authorized XML supplied by the user. Do not treat a
44-digit key, a DANFE PDF, or a public consultation page as equivalent to the signed
XML. Assess each additional retrieval route with its own state, access, authorization,
and item-detail limitations before committing to support. The national public NF-e
consultation currently presents a browser challenge; automatic key-only import must
not bypass it or be advertised without a legitimate supported access path. Official
DF-e distribution is a separate, authorized workflow—not a generic public XML lookup.

Official references: [NF-e public consultation](https://www.nfe.fazenda.gov.br/portal/consultaRecaptcha.aspx?tipoConsulta=completa)
and [NF-e distribution technical specification](https://www.nfe.fazenda.gov.br/POrtal/exibirArquivo.aspx?conteudo=155Wx5%2FJB5A%3D).

## Investigation before schema or UI changes

Build a field inventory using sanitized real-world examples of model-55 XML and the
existing model-65 imports. For each candidate field, record source tag, semantics,
precision, optionality, transaction/line-item/provenance destination, and whether it
affects the amount actually paid. At minimum analyze:

| Area | Questions to resolve |
|---|---|
| Identity and status | Access key, model, issuer/recipient, issue time, authorization protocol, cancellation/denial, and correction events: what is safe to import or show? |
| Product rows | Description, code, quantity, unit, unit price, product value, per-item discount, and any item-level charges: which need new `LineItem` fields versus source metadata? |
| Document adjustments | Freight, insurance, other charges, document discounts, taxes, and rounding: which are paid amounts, which are informative tax components, and how are they allocated or shown? |
| Payment | Payment methods, installments, change, and payable total: which value should become the transaction price, especially when invoice and cash movement differ? |
| Evidence | Original authorized XML, DANFE, consultation snapshots, extraction provenance, and parser version: what must be retained without duplicating unnecessary files? |

The investigation must include at least one ordinary invoice, one discounted invoice,
one with freight/other charges, and an adjustment-heavy or inconsistent document. Do
not assume every fiscal total is the cash/card amount or sum tax components twice.

## Proposed user contract

1. An accepted source produces an unsaved cash/card Split Purchase draft through the
   existing NARUTO-02 form; the user reviews and completes normal transaction fields.
2. Keep the original fiscal values and source provenance. Never silently rewrite item
   prices to force the draft to balance.
3. Show source item sum, document adjustments, fiscal total, intended transaction
   amount, and any unresolved difference in a way the user can inspect. Decide whether
   explicit adjustment line items or dedicated fields are appropriate only after the
   field investigation and examples.
4. If the amounts cannot be reconciled under the chosen representation, require a
   visible manual resolution before saving; do not create a misleading transaction.
5. Reuse NARUTO-03's private attachment/evidence and draft-inbox flow. Apply its
   10 MiB-per-file and five-file-per-record limits; do not weaken authorization.

## Development slices

1. **Source and field analysis:** collect sanitized fixtures, document source support
   and legal/technical lookup limits, publish the field matrix and reconciliation
   examples, and choose the data representation with a migration plan if needed.
2. **Model-55 XML parser:** validate model, access key, status, authorization, and
   bounded XML input; normalize product rows and monetary values without losing
   precision or provenance. Keep model-65 behavior unchanged.
3. **Review and reconciliation:** add the chosen fields/summary to the existing draft
   and cash/card form, expose discrepancies and manual correction, preserve attachments,
   and maintain the exact-sum save guard.
4. **Additional sources only if proven feasible:** evaluate DANFE text and authorized
   retrieval separately. A scanned PDF or screenshot belongs to NARUTO-08 OCR, not
   an implicit NF-e parser fallback.
5. **Verification:** service, request, and browser coverage for success, malformed and
   unsupported input, missing/cancelled authorization, adjustment math, unresolved
   differences, cash/card drafts, and attachment handoff; then manual testing and CI.

## Open product decisions

- How should discounts, freight, insurance, and other paid adjustments appear in a
  transaction: dedicated fields, explicit adjustment line items, or user-assigned
  allocation? What must reports and rollback preserve?
- Should payment method from the document suggest cash versus card, or remain
  provenance only? Never infer a specific user card/account from fiscal data alone.
- Which NF-e lookup or distribution path, if any, is authorized and maintainable for
  this application's users without solving a browser challenge or requiring paid
  third-party access?

Completion requires the field analysis, chosen reconciliation contract, implemented
model-55 source path, tests, and manual validation. Broader state/portal coverage is
optional and must be documented honestly.
