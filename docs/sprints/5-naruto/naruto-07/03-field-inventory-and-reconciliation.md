# NARUTO-07 — Field inventory and reconciliation

## Status and current implementation

This is an investigation worksheet, not a complete NF-e specification. The tag names
below describe fields already read in the code; candidate fields must be checked against
official layouts and sanitized fixtures before their semantics or formulas are locked.

| Source | Currently extracted | Known limitation |
|---|---|---|
| Supplied XML | `infNFe/@Id`, `ide/mod`, `protNFe/infProt/cStat`, issuer name, issue time, `ICMSTot/vNF`, and item descriptions/amounts | Parser accepts status 100 or 150 and checks key format/model, but does not compare protocol key, verify signature, or establish later cancellation status. |
| XML items | `vProd - vDesc + vFrete + vSeg + vOutro` per product | The resulting draft item is already adjusted. Original `vProd` and the component adjustments are not retained in the normalized item. |
| Goiás NFC-e consultation | Item descriptions and displayed row amounts, displayed payable total, key, issuer, issue time | The parser does not extract the displayed document discount; it can leave a difference. Separate consultation evidence is retained. |
| Paraná NFC-e consultation | Item descriptions and displayed row amounts, displayed payable total, key, issuer, issue time | Adjustment information is not currently normalized; verify availability with fixtures before promising it. |

The normalized `FiscalReceipts::Draft` currently has access key, issuer, issue time,
total cents, item description/price, and source. `difference_cents` is document total
minus item sum. The saved inbox permits those fields and requires nonnegative item
amounts. The final cash/card transaction does not have a dedicated fiscal-key identity.
The import UI negates item and parent amounts when preparing an expense.

The existing `LineItem` validation requires item prices to have the same sign as the
parent transaction, and the parent requires their sum to equal its price. Therefore a
positive R$10 discount row under a negative R$109.95 expense is **not currently
valid**. The user has chosen a dedicated discount line created only through Add Discount
or fiscal import, with permanent DISCOUNT category, no entity, and first position.
Supporting it requires an explicit model, allocation, reporting, and rollback design;
it must not be treated as ordinary positive income by accident.

## Fields to investigate

| Area | Candidate information | Precision and destination questions |
|---|---|---|
| Identity | Key, model, issuer, recipient, issue timestamp, protocol key/status, later events | Which information is needed to identify duplicates and display status? Which is evidence-only? A supplied protocol is not proof of current status. |
| Product | Product code/name, quantity, unit, unit price, gross product amount | Currency totals use cents; quantity and unit price may need more precision. Preserve original values and avoid rounding each quantity calculation prematurely. |
| Item adjustments | Discount, freight, insurance, other charges and applicable tax components | Are they already included in the represented item amount? Preserve source components so they cannot be applied twice. |
| Document totals | Product total, discounts, freight, insurance, other charges, taxes, fiscal total | Determine what affects payable total for each source/fixture; informative taxes are not automatically extra charges. |
| Payment | Payment methods, amounts, change and any installment information | Distinguish fiscal total from actual payment; do not infer a specific account or card. Determine how split payments are handled. |
| Provenance | Source type, original document/evidence, parser version, values modified by the user | Preserve enough to explain the result without leaking identifiers in logs or weakening attachment ownership. |

## Reconciliation examples for the decision

The following is arithmetic for product review, not a claim about how every fiscal
document encodes its adjustments:

| Example | Original items | Recognized adjustments | Document total | Unexplained difference |
|---|---:|---:|---:|---:|
| Goiás reported receipt | R$119.95 | Discount −R$10.00 | R$109.95 | R$0.00 |
| Charge example | R$100.00 | Freight +R$8.00 | R$108.00 | R$0.00 |
| Unresolved | R$100.00 | None recognized | R$103.00 | R$3.00 |

Define the formula using a consistent sign convention: original item sum plus
recognized signed adjustments must equal the document total, with any residual shown
explicitly. If item prices already include an adjustment, exclude that same amount
from the additional adjustment sum. The payable amount and the amount the user chooses
to record may differ; the product decision must specify when that is allowed and how
it is shown. A residual is not automatically a discount, freight, tax, or rounding.

## Open decisions

1. The user chose a dedicated first discount line with original product amounts preserved,
   fixed DISCOUNT category, no entity, and removal support. A transaction has at most
   one discount line. Reports retain the original product-category amounts and show
   the discount separately under DISCOUNT: R$100 Food and R$10 DISCOUNT yield R$90
   net expense. Source-identified freight appears as a separate charge line: R$100
   products plus R$10 freight yields R$110. Treatment of insurance and other charges
   requires fixture-based investigation; unsupported residuals remain visible.
2. The user chose to warn on completed transactions in the current context and allow an
   explicit intentional repeat. For saved receipts, warn and offer to open the existing
   receipt or explicitly save another; saved receipts are user-owned without a context.
   Deleted records do not trigger warnings; existing drafts count until deleted or consumed.
3. The user chooses cash or card; the document's payment method does not choose the
   form. How mixed payments are represented remains to investigate; never select a
   specific account or card solely from fiscal data.
4. Exact status and source-verification claims for each supported route, based on
   official references and sanitized examples.
