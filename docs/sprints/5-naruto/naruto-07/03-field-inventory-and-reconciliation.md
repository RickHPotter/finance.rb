# NARUTO-07 — Field inventory and reconciliation

## Status and current implementation

This is an investigation worksheet, not a complete NF-e specification. The tag names
below describe fields already read in the code; candidate fields must be checked against
official layouts and sanitized fixtures before their semantics or formulas are locked.

## Slice 0 source review

The [official NF-e manual's validation rule W16-10](https://www.nfe.fazenda.gov.br/portal/exibirArquivo.aspx?conteudo=nebWFce4X9o%3D)
illustrates that `vNF` can depend on products, discounts, freight, insurance, other
charges, and several tax components, with documented exceptions. This older manual is
evidence that a simplistic product-minus-discount formula is insufficient, not a current
complete formula. The [official NF-e document index](https://www.nfe.fazenda.gov.br/portal/listaConteudo.aspx?tipoConteudo=ndIjl%2BiEFdE%3D)
lists the newer manuals; validate applicable versions and technical notes before
claiming broad coverage. An [earlier field manual](https://www.nfe.fazenda.gov.br/portal/exibirArquivo.aspx?conteudo=HO2V%2BvzhFBk%3D)
also distinguishes quantity and unit-price precision from currency totals. Do not
recalculate original product totals from rounded unit prices.

The synthetic examples in `spec/fixtures/files/fiscal_naruto_07/` cover ordinary,
discounted, freight, and unresolved model-55 fragments, a model-65 discount fragment,
and a GO-shaped discount HTML excerpt. They contain fictitious identities and are
neither signed nor schema-complete; the GO excerpt illustrates expected shape, not a
verified live SEFAZ response. Real sanitized examples and current official status,
authorization, and layout confirmation remain necessary for manual acceptance.

XML reports item and document adjustment totals at different levels. The document
total is not an additional charge on top of the same item totals: recognize a source
adjustment once, preserve its components, and leave inconsistent values unresolved.
The GO adapter recognizes specific displayed discount and freight labels; PR currently
reads product rows and payable totals. Availability and meaning of displayed adjustments
require source-specific real-fixture verification.

| Source | Currently extracted | Known limitation |
|---|---|---|
| Supplied XML | `infNFe/@Id`, `ide/mod`, protocol status and key, issuer name, issue time, `ICMSTot` amounts, and item descriptions/amounts | Parser accepts status 100 or 150, requires the matching protocol key for model 55 and checks it for model 65 when present. It does not verify signature or later cancellation status. |
| XML items | Original `vProd`, item adjustments, quantity, unit, unit price, and code | Gross product values remain in draft lines; source adjustment amounts are retained separately. Unsupported components remain in the difference. |
| Goiás NFC-e consultation | Item descriptions and displayed row amounts, payable total, recognized displayed discount/freight, key, issuer, issue time | Adjustment labels are covered by synthetic markup only. Separate consultation evidence is retained. |
| Paraná NFC-e consultation | Item descriptions and displayed row amounts, displayed payable total, key, issuer, issue time | Adjustment information is not currently normalized; verify availability with fixtures before promising it. |

The normalized `FiscalReceipts::Draft` currently has access key, issuer, issue time,
total cents, item description/price, source, recognized adjustments, and XML source
details. `difference_cents` is document total minus item sum plus discount minus freight.
The saved inbox preserves these fields. New cash/card transactions can carry a signed,
user-scoped fiscal identity. The import UI negates product, freight, and parent amounts
when preparing an expense and uses a positive dedicated discount line.

Product line prices have the same sign as the parent, and the parent requires line
prices to sum to its price. A dedicated positive discount line is allowed for an expense
with the permanent DISCOUNT category and no entity. It is shown first and reported
separately from ordinary income.

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
