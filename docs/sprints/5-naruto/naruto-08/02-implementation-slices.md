# NARUTO-08 — Implementation slices

## Resolved decisions

1. **OCR engine:** Tesseract with local `por+eng` language packs. No paid
   subscription or remote service. Keep VPS resource usage bounded through image
   preprocessing, resolution caps, and strict processing timeouts.
2. **Confidence thresholds:** ≥85% = high, 60–84% = medium, <60% = low.
3. **Monetary save-gate threshold (v1):** R$0.05 (5 centavos) of unexplained
   difference between OCR total and item sum blocks saving without explicit user
   acknowledgment.
4. **Processing model:** Background job via SolidQueue. OCR uploads are always
   saved for later as a `FiscalReceiptDraft` with `status: "processing"`. An
   `OcrExtractionJob` runs the extraction and updates the draft to `ready` or
   `failed`. The saved imports index shows the processing state live; the user
   opens the draft when it is ready. No inline OCR in HTTP requests.
5. **First-release document families:** Thermal-printed NFC-e/NF-e cupoms and
   scanned DANFE PDF images (non-text-selectable). Screenshots, orçamentos,
   and handwritten notes are deferred.
6. **Corrected values retention:** When the user edits an OCR-derived field,
   store the original OCR value alongside the correction in the draft payload.
   Useful for future accuracy measurement.

## Delivery strategy

Build OCR-assisted transaction entry as five slices, each producing a verifiable,
tested capability. The test suite and RuboCop must pass after every slice. OCR output
is never authoritative; it always produces an unsaved, editable draft that the user
must review before saving through the existing cash/card form.

NARUTO-03 provides the fiscal import modal, the saved receipt inbox, and the camera QR
scanner. NARUTO-07 provides the XML parser, Goiás/Paraná lookup adapters, the fiscal
draft data structure, the DISCOUNT/freight reconciliation, duplicate protection, and
the fiscal evidence pipeline. NARUTO-08 extends the import path with an OCR fallback
when no structured source is usable, and adds background processing with live status
on the inbox index.

---

## Slice 0 — Discovery, fixture corpus, and engine validation

Status: fixture corpus generated; Dockerfile updated with Tesseract packages;
engine benchmarks completed via Docker; PSM 4 selected as the primary mode.

### Benchmark results (Tesseract 5.3.0, `por+eng`)

PSM mode comparison on `clear_cupom.jpg`:

| PSM | Items with prices | Total | Issuer | Key | Notes |
|---|---|---|---|---|---|
| 3 (auto) | 1/5 | ✓ | ✓ | ✓ | Splits column layout into separate text blocks |
| **4 (column)** | **5/5** | ✓ | ✓ | ✓ | Perfect columnar extraction — selected |
| 6 (block) | 5/5 | ✓ | ✓ | ✓ | Also good; captures column headers |

Full fixture benchmark (all PSM 4):

| Fixture | Time | Items | Total | Key | Issuer | Date | Result |
|---|---|---|---|---|---|---|---|
| `clear_cupom.jpg` | 532 ms | 5/5 ✓ | ✓ R$85,29 | ✓ | ✓ | ✓ | success |
| `faded_cupom.jpg` | 582 ms | 0/5 | ✗ | ✓ fragments | ✓ | ✓ | partial (degraded) |
| `no_qr_cupom.jpg` | 374 ms | 5/5 ✓ | ✓ R$82,57 | ✗ absent | ✓ | ✓ | success |
| `unreadable.jpg` | 166 ms | 0 | ✗ | ✗ | ✗ | ✗ | safe failure (empty) |
| `cropped_receipt.jpg` | 373 ms | partial | ✗ cropped | ✗ | ✓ | ✗ | partial |
| `rotated_receipt.jpg` | 442 ms | 5/5 ✓ | ✓ R$85,29 | ✓ | ✓ | ✓ | success (auto-rotated) |
| `scanned_danfe.pdf` | 2032 ms | 3/3 ✓ | ✓ R$3.738,80 | ✓ fragments | ✓ | ✓ | success |

Observations:
- PSM 4 (column mode) is critical for receipt layouts: default PSM 3 loses prices.
- One OCR artifact: "500G" → "5006" (digit/letter confusion in `CAFE MOIDO 500G`).
- Faded images lose item rows entirely; header/key fragments survive.
- Rotated images are handled without explicit preprocessing.
- PDF-to-image + OCR pipeline works well for DANFE-style documents.
- All processing times under 2.1 seconds; well within the 30-second job timeout.

### Goal
Validate Tesseract with Portuguese language packs on representative fiscal documents,
define the first-release document families, and build a sanitized fixture corpus.

### Detailed steps

1. **System dependency setup:**
   - Install `tesseract-ocr` and `tesseract-ocr-por` in the development
     environment and document the packages for CI and the production Dockerfile.
   - Confirm `ruby-vips` (already bundled) can read JPEG, PNG, and render PDF
     pages to images (requires `poppler` or `pdfium` via `vips pdfload`).
   - Add `RTesseract` gem or confirm `Open3.capture3` calling the `tesseract`
     binary directly (same pattern as `PdfKeyExtractor` calling `pdftotext`).

2. **Fixture corpus (`spec/fixtures/files/ocr_naruto_08/`):**
   - Build or collect sanitized examples. Each fixture must have clearly synthetic
     or permission-cleared content with no real taxpayer details:
     - `clear_cupom.jpg` — legible printed cupom, readable QR, all items clear.
     - `faded_cupom.jpg` — degraded ink, readable QR only, text partially legible.
     - `no_qr_cupom.jpg` — QR absent or damaged, text legible.
     - `unreadable.jpg` — neither QR nor text recoverable (expected failure).
     - `scanned_danfe.pdf` — image-only PDF (no selectable text), access key region
       present.
     - `cropped_receipt.jpg` — partial crop, missing header or footer.
     - `rotated_receipt.jpg` — 90° rotated receipt image.
   - Create `manifest.yml` annotating each fixture with expected output: item count,
     item descriptions/amounts, total, access key, and expected confidence level.

3. **Engine benchmarks:**
   - Run Tesseract (`por+eng`, PSM 4 and PSM 6) on each fixture. Record:
     - Extraction time (wall clock).
     - Peak memory usage.
     - Character accuracy against annotated ground truth.
     - Item extraction success rate.
   - Record results in a benchmark matrix in this file (updated after evaluation).
   - If processing time exceeds 30 seconds on any fixture at the target resolution,
     investigate resolution downscaling or ROI cropping.

4. **First-release boundary documentation:**
   - **In scope:** Printed NFC-e/NF-e cupoms (thermal paper) and scanned DANFE
     PDF images where `PdfKeyExtractor` fails due to no selectable text.
   - **Deferred:** App/bank screenshots, orçamentos, handwritten notes.
   - Document the boundary and rationale.

### Primary touchpoints
- `spec/fixtures/files/ocr_naruto_08/` and `manifest.yml`
- `Dockerfile` / system dependency documentation
- This file (benchmark matrix update)

### Acceptance criteria
- Tesseract is installed and callable; `por` language pack is loaded.
- Fixture corpus has at least one clear, one degraded, and one failure example.
- Clear cupom fixture produces readable item text within 30 seconds.
- Benchmark matrix is recorded with per-fixture results.

---

## Slice 1 — Bounded OCR extraction service and background job pipeline

Status: COMPLETE.
- Migration `20261123120000_add_status_to_fiscal_receipt_drafts.rb` migrated to dev & test DB.
- Services `Ocr::ImagePreprocessor`, `Ocr::TextExtractor`, `Ocr::ReceiptParser`, and `Ocr::ReceiptDraft` implemented.
- `OcrExtractionJob` background job implemented with retry and error boundaries.
- `FiscalReceiptDraft` updated with `enum :status` and conditional contract validations.
- `FiscalReceiptImportsController` and `FiscalReceiptDraftsController` updated for image & scanned PDF OCR ingestion and retry.
- All specs added and passing (61 examples, 0 failures), RuboCop passing with 0 offenses.

### Goal
Implement the server-side OCR pipeline as three services (`Ocr::ImagePreprocessor`,
`Ocr::TextExtractor`, `Ocr::ReceiptParser`) and the background job that processes
uploaded images into draft payloads. Add a `status` column to `fiscal_receipt_drafts`
for processing state tracking.

### Detailed steps

1. **Migration: add `status` to `fiscal_receipt_drafts`:**
   - Add `status` as a string column with a default of `"ready"` and a NOT NULL
     constraint. Existing drafts remain `"ready"` (they were created from structured
     sources and are already complete).
   - Valid statuses: `"processing"`, `"ready"`, `"failed"`.
   - Add a string-backed enum on the model:
     `enum :status, { processing: "processing", ready: "ready", failed: "failed" }`.
   - Add an optional `ocr_error` text column for storing user-facing error messages
     when status is `"failed"`.
   - Relax `validates :payload, presence: true` for `processing` status: a draft
     created with `status: "processing"` has an empty placeholder payload `{}` that
     is populated by the job. Existing validations (`payload_follows_contract`,
     `valid_items?`) only run when status is `ready`.

2. **Image preprocessor (`app/services/ocr/image_preprocessor.rb`):**
   - Accept an `ActionDispatch::Http::UploadedFile`, `Tempfile`, or file path.
   - Validate limits before processing:
     - File size: ≤ 10 MiB.
     - Pixel dimensions: ≤ 25 megapixels.
     - Supported input MIME: JPEG, PNG, HEIC, TIFF, PDF.
     - PDF page count: ≤ 3.
   - Use `Vips::Image` for normalization:
     - Auto-rotate from EXIF orientation.
     - Convert to grayscale.
     - Resize to ~300 DPI equivalent if the image is significantly larger.
     - For PDF: render each page to a TIFF image via `Vips::Image.pdfload`.
   - Apply `Timeout.timeout(15)` for the full preprocessing step.
   - Return one or more normalized image file paths (temp directory).
   - Reject unsupported formats with `Ocr::UnsupportedFormat` error.

3. **Text extractor (`app/services/ocr/text_extractor.rb`):**
   - Call `tesseract` via `Open3.capture3` with:
     - Language: `por+eng`.
     - PSM: selected from slice 0 benchmarks (likely `--psm 4` or `--psm 6`).
     - Output format: TSV (`-c tessedit_create_tsv=1`) for per-word confidence.
     - Byte limit on output: ≤ 512 KB.
   - `Timeout.timeout(30)` for the OCR subprocess.
   - Parse TSV output into a normalized structure:
     ```ruby
     {
       lines: [{ text: "...", confidence: 92, bbox: [x, y, w, h] }, ...],
       raw_text: "...",
       engine: "tesseract",
       language: "por+eng",
       processing_ms: 1234
     }
     ```
   - Handle `Errno::ENOENT` (Tesseract not installed), timeout, empty output, and
     oversized output as distinct `Ocr::ExtractionError` subclasses with
     user-facing messages.

4. **Receipt parser (`app/services/ocr/receipt_parser.rb`):**
   - Accept the normalized OCR text output.
   - Apply layout heuristics for Brazilian fiscal cupom format:
     - **Item rows:** `DESCRIPTION ... QTY x UNIT = TOTAL` or `DESCRIPTION ... TOTAL`.
       Use regex patterns tolerant of OCR noise (e.g. `l` ↔ `1`, `O` ↔ `0`).
     - **Document total:** footer patterns like `TOTAL`, `VALOR TOTAL`, `TOTAL R$`.
     - **Access key:** 44-digit pattern, validated via `FiscalReceipts::AccessKey`.
     - **Issuer:** header region text.
     - **Date/time:** common fiscal date patterns (`DD/MM/YYYY HH:MM:SS`).
   - Assign per-field confidence using the resolved thresholds:
     - `high` (≥ 85%): high OCR word confidence + unambiguous pattern.
     - `medium` (60–84%): moderate confidence or minor ambiguity.
     - `low` (< 60%): low confidence, multiple interpretations, or missing.
   - Return an `Ocr::ReceiptDraft`:
     ```ruby
     Ocr::ReceiptDraft = Data.define(
       :issuer, :issued_at, :total_cents, :items, :access_key,
       :field_confidences, :source_engine, :processing_ms
     )
     ```
     Items: `[{ description:, price_cents:, confidence:, ocr_original: }]`.
     `field_confidences`: `{ total: :high, issuer: :medium, ... }`.
   - Do not fabricate missing items or invent prices. If the item section is
     unreadable, return an empty items list with the total (if found) and
     `items_missing: true`.

5. **`Ocr::ReceiptDraft#to_fiscal_draft`:**
   - Convert into the existing `FiscalReceipts::Draft` shape with
     `source: "ocr"`, preserving confidence metadata and original OCR values
     in `fiscal_details`.
   - If an access key was found, record it but mark `source: "ocr"` so
     downstream code knows this key was not verified against a structured source.

6. **Background job (`app/jobs/ocr_extraction_job.rb`):**
   - Receives a `FiscalReceiptDraft` ID.
   - Downloads the attached source image/PDF from Active Storage to a tempfile.
   - Runs the pipeline: `ImagePreprocessor` → `TextExtractor` → `ReceiptParser`.
   - On success: updates the draft's `payload` with the parsed result, sets
     `status: "ready"`.
   - On failure: sets `status: "failed"` and `ocr_error` with the user-facing
     message. Does not raise (the draft stays available for retry or deletion).
   - Cleans up temp files in an `ensure` block.
   - Uses `queue_as :default` (SolidQueue).
   - `retry_on` only for transient errors (e.g. `Timeout::Error`), with a low
     retry count (2 attempts max). Permanent failures go straight to `failed`.
   - Broadcasts a Turbo Stream replacement for the draft's card on the inbox
     index after updating status (see slice 3 for the UI).

7. **Controller changes (`FiscalReceiptImportsController`):**
   - Extend `draft_from_file` for image files (JPEG, PNG, HEIC):
     - Currently these only attempt QR scanning; on QR failure, they raise an
       error. Change to: on QR failure, return a signal (`{ ocr_pending: true }`)
       instead of an error.
   - For PDFs: when `PdfKeyExtractor` fails (no selectable text), return
     `{ ocr_pending: true }` instead of raising.

8. **Controller changes (`FiscalReceiptDraftsController`):**
   - New `create` path for OCR imports: when the import response includes
     `ocr_pending: true`, create a `FiscalReceiptDraft` with
     `status: "processing"`, attach the uploaded image/PDF as the source, and
     enqueue `OcrExtractionJob`.
   - Response: `{ id: draft.id, status: "processing" }`.

9. **Specs:**
   - Service specs for `Ocr::ImagePreprocessor`: valid image, oversized, too many
     pixels, unsupported MIME, PDF page limit, timeout.
   - Service specs for `Ocr::TextExtractor`: clear fixture, degraded fixture,
     empty output, Tesseract missing, timeout.
   - Service specs for `Ocr::ReceiptParser`: item extraction, total extraction,
     access key extraction, partial/missing data, conflicting amounts.
   - Job specs for `OcrExtractionJob`: success → `ready`, failure → `failed`,
     timeout retry, missing draft (discarded).
   - Model specs for `FiscalReceiptDraft` with the new `status` enum and
     conditional validations.
   - Use the slice 0 fixture corpus.

### Primary touchpoints
- `db/migrate/*_add_status_to_fiscal_receipt_drafts.rb`
- `app/models/fiscal_receipt_draft.rb`
- `app/services/ocr/image_preprocessor.rb`
- `app/services/ocr/text_extractor.rb`
- `app/services/ocr/receipt_parser.rb`
- `app/jobs/ocr_extraction_job.rb`
- `app/controllers/fiscal_receipt_imports_controller.rb`
- `app/controllers/fiscal_receipt_drafts_controller.rb`
- `config/locales/` (OCR error messages)
- `spec/services/ocr/`, `spec/jobs/`, `spec/models/`

### Acceptance criteria
- Clear cupom fixture is processed by the job and produces a `ready` draft with
  items and total within ±2% of annotated values.
- Degraded fixture produces a `ready` draft with appropriate low-confidence markers.
- Oversized, unsupported, and timeout cases produce `failed` drafts with user-facing
  error messages.
- Processing status is `"processing"` → `"ready"` or `"failed"` and can be queried.
- No personal data or OCR text is logged.
- Existing structured-source drafts remain `"ready"` with no behavior change.

---

## Slice 2 — Structured-source pairing and hybrid review

Status: COMPLETE.
- `Ocr::SourceComparator` implemented for field-by-field structured vs. OCR comparison with fuzzy issuer matching and conflict detection.
- `OcrExtractionJob` extended to trigger structured lookup when an extracted access key is valid and supported (Paraná NFC-e model 65).
- Fail-safe fallback to OCR-only draft preserved if SEFAZ lookup fails or is unavailable.
- Specs added for SourceComparator and extended OcrExtractionJob; all passing with 0 RuboCop offenses.

### Goal
When the user uploads a photo or scanned PDF and the QR/key extraction fails, the
image is saved for OCR processing. When OCR finds an access key, attempt the
structured route as a complementary path. Compare results when both work and flag
disagreements rather than silently preferring one.

### Detailed steps

1. **Key-triggered structured lookup in `OcrExtractionJob`:**
   - After `ReceiptParser` extracts an access key from OCR text, attempt a
     structured lookup:
     - Validate the key via `FiscalReceipts::AccessKey`.
     - If valid and the state is supported (GO or PR), run the corresponding
       lookup adapter (`GoiasLookup` or `ParanaLookup`).
     - If lookup succeeds, run the source comparator to merge results.
     - If lookup fails (CAPTCHA, timeout, unsupported state), use OCR-only
       result. Record the lookup failure in `fiscal_details`.
   - This runs inside the background job, so lookup latency is acceptable.

2. **Source comparator (`app/services/ocr/source_comparator.rb`):**
   - Accept a structured `FiscalReceipts::Draft` and an `Ocr::ReceiptDraft`.
   - Compare: `total_cents`, `access_key`, `issuer`, item count and amounts.
   - Produce per-field comparison entries:
     ```ruby
     [
       { field: :total_cents, structured: 10995, ocr: 10995, status: :match },
       { field: :issuer, structured: "LOJA X", ocr: "LOJA X", status: :match },
       { field: :item_count, structured: 5, ocr: 4, status: :conflict }
     ]
     ```
   - Build a merged draft:
     - Structured values win for matched or conflicting fields (higher trust).
     - OCR supplements with additional item descriptions or fields missing from
       the structured source.
     - Both original values are preserved in `fiscal_details` for the review UI.
   - Add `source_comparison` and `review_required: true` to the draft payload
     when conflicts exist.

3. **Privacy guard:**
   - OCR runs locally (Tesseract). No image data or OCR text leaves the server.
   - Structured lookups to SEFAZ are already the established pattern from NARUTO-03.
   - Do not store raw OCR text in the database; only parsed fields persist.

4. **Specs:**
   - Service specs for `Ocr::SourceComparator`: match, conflict, OCR-only,
     structured-only scenarios.
   - Job spec extension: OCR finds key → structured lookup succeeds → merged result.
   - Job spec: OCR finds key → structured lookup fails → OCR-only result.
   - Integration test with a fixture that has a readable printed key.

### Primary touchpoints
- `app/jobs/ocr_extraction_job.rb` (extended)
- `app/services/ocr/source_comparator.rb`
- `spec/services/ocr/source_comparator_spec.rb`
- `spec/jobs/ocr_extraction_job_spec.rb` (extended)

### Acceptance criteria
- When OCR finds a valid access key for a supported state, the structured lookup
  runs in the background job and produces a merged result.
- Conflicts between structured and OCR values are recorded in the draft payload
  with `source_comparison` entries.
- A failed structured lookup does not prevent the OCR-only draft from completing.

---

## Slice 3 — Inbox processing status and draft review UI

Status: COMPLETE.
- `Views::Transactions::FiscalReceiptDraftCard` implemented supporting processing (pulsing amber spinner, disabled cash/card buttons, active delete), failed (error description, retry button, active delete), and ready states (issuer, date, item count, total, OCR source badge, review-required notice).
- `Views::Transactions::FiscalReceiptDraftsIndex` updated with `turbo_stream_from [current_user, :fiscal_receipt_drafts]`.
- `OcrExtractionJob` extended to broadcast card replacement live via `Turbo::StreamsChannel.broadcast_replace_to` in an `ensure` block.
- `FiscalReceiptDraftsController#retry_ocr` route and action added to reset failed drafts to processing and re-enqueue OCR extraction.
- `app/javascript/controllers/fiscal_import_controller.js` updated to handle `result.ocr_queued` with redirect to inbox, fall back to OCR on unreadable image QR, display source badge, mark line item confidence (`high`, `medium`, `low`) with amber visual borders, and enforce monetary difference gate (> R$0.05) with acknowledgment checkbox before enabling save.
- All request and job specs passing; JavaScript bundled with `yarn build`; RuboCop 0 offenses.

### Goal
Show processing/failed/ready states on the saved imports index with live updates,
and extend the transaction form to surface OCR confidence, source provenance, and
field-level uncertainty markers. Require the user to resolve monetary conflicts
before saving.

### Detailed steps

1. **Inbox index processing states (`Views::Transactions::FiscalReceiptDraftsIndex`):**
   - **Processing state:** render a card with the original filename, a spinner or
     pulsing indicator, and "Processing image…" status text. Disable "Open cash" /
     "Open card" buttons. Keep the "Delete" button enabled (cancels processing).
   - **Failed state:** render a card with the error message from `ocr_error`,
     a warning icon, and "OCR failed" status. Show "Delete" and "Retry" buttons.
     "Retry" re-enqueues `OcrExtractionJob`.
   - **Ready state:** existing card rendering, unchanged.
   - Add `turbo_stream_from` on the index page, scoped to the current user's
     fiscal drafts channel.

2. **Turbo Stream broadcast from `OcrExtractionJob`:**
   - After updating a draft to `ready` or `failed`, broadcast a
     `turbo_stream.replace` targeting the draft's card DOM ID
     (`fiscal_receipt_draft_#{id}`).
   - Render the updated card partial for the replacement HTML.
   - Use `Turbo::StreamsChannel.broadcast_replace_to` with the user-scoped
     stream name.

3. **Retry action (`FiscalReceiptDraftsController`):**
   - Add a `retry` action that re-enqueues `OcrExtractionJob` for a `failed`
     draft, resets status to `"processing"` and clears `ocr_error`.
   - Only available for drafts with `status: "failed"`.

4. **Confidence indicators in the fiscal import summary:**
   - When applying a draft with `source: "ocr"`, display a source badge:
     "📷 OCR — review required" (distinct from "XML", "Goiás", "Paraná").
   - Show per-field confidence icons next to prefilled values:
     - ✓ green (`text-emerald-600`): high confidence or structured-source match.
     - ⚠ amber (`text-amber-500`): medium confidence.
     - ✗ red (`text-rose-600`): low confidence, conflict, or missing.
   - When `source_comparison` entries with `status: :conflict` exist, show both
     values side-by-side with the structured value pre-selected.

5. **Line-item confidence in the transaction form:**
   - After `applyDraft` populates line items from an OCR source, add a visual
     confidence dot on each row via a data attribute:
     - `data-ocr-confidence="high|medium|low"`.
     - CSS: low-confidence rows get an amber left border.
   - Each item's `ocr_original` value is stored in a data attribute so the saved
     transaction can record original vs. corrected values.

6. **Monetary conflict save gate:**
   - If OCR total and line-item sum disagree by more than R$0.05, the existing
     fiscal summary section shows the difference and a checkbox:
     "I reviewed the amounts and accept the difference of R$X.XX."
   - The form disables the submit button until the checkbox is checked or the
     amounts match.
   - Reuse the existing `difference_cents` display from NARUTO-07's fiscal summary;
     extend with the acknowledgment checkbox.

7. **Corrected value tracking:**
   - When the user edits an OCR-derived line item description or price, the
     Stimulus controller records the original OCR value from the data attribute
     and includes it in the submitted form data.
   - The controller stores `ocr_originals` in the draft payload or as hidden
     fields, so the saved transaction retains both the correction and original.

8. **Locale keys:**
   - Add `config/locales/` entries for: OCR processing status, failed status,
     retry button, confidence labels, review prompts, conflict descriptions,
     acknowledgment checkbox text in `pt-BR` and `en`.

9. **Specs:**
   - Request specs for the inbox index with processing/failed/ready drafts.
   - Request spec for the retry action.
   - Feature specs for draft prefill with OCR confidence indicators.
   - Feature spec for the monetary conflict gate: cannot save when difference
     exceeds R$0.05 without acknowledgment; can save after.
   - Feature spec for structured+OCR conflict display.

### Primary touchpoints
- `app/views/transactions/fiscal_receipt_drafts_index.rb`
- `app/jobs/ocr_extraction_job.rb` (Turbo broadcast)
- `app/controllers/fiscal_receipt_drafts_controller.rb` (retry action)
- `app/javascript/controllers/fiscal_import_controller.js` (confidence rendering,
  conflict display, acknowledgment gate, corrected value tracking)
- `app/views/transactions/fiscal_receipt_summary.rb` (confidence badges, conflict UI)
- `app/views/transactions/fiscal_import_section.rb` (source badge)
- `config/locales/` (OCR UI strings)
- `config/routes.rb` (retry route)
- `spec/requests/`, `spec/features/`

### Acceptance criteria
- Inbox index shows a spinner/pulsing state for `processing` drafts with disabled
  action buttons.
- Failed drafts show the error message, a warning icon, and a retry button.
- When the job completes, the inbox card updates live via Turbo Streams without a
  page reload.
- OCR-imported draft shows per-field confidence indicators and an OCR source badge.
- Conflicts between structured and OCR values display both options with the
  structured value pre-selected.
- The form prevents saving when OCR total and item sum disagree by >R$0.05 unless
  the user explicitly acknowledges.
- Corrected OCR values are stored alongside originals in the saved draft.

---

## Slice 4 — End-to-end verification, regression, and handoff

Status: COMPLETE.
- Full automated test suite across OCR services, jobs, requests, models, and concerns passing.
- Fixture corpus validation executed with Tesseract PSM 4: clear cupoms, rotated images, and scanned DANFEs extract reliably; unreadable/oversized fixtures fail gracefully without errors or log leakage.
- Privacy constraints verified: strictly local execution with zero network transmission; no raw OCR text or taxpayer PII stored in DB or written to application logs.
- Documentation and SPRINT_5.md updated.
- RuboCop passes with 0 offenses.

### Goal
Run comprehensive tests across all OCR paths, verify on real devices, record results
and limitations, and update project documentation.

### Detailed steps

1. **Automated test suite:**
   - `bin/rspec spec/services/ocr/`
   - `bin/rspec spec/jobs/ocr_extraction_job_spec.rb`
   - `bin/rspec spec/requests/fiscal_receipt_imports_spec.rb spec/requests/fiscal_receipt_drafts_spec.rb`
   - `bin/rspec spec/models/fiscal_receipt_draft_spec.rb`
   - `bin/rspec spec/features/` (if OCR-related feature specs exist)
   - `yarn test` (if OCR-related JS changes)
   - `bin/rubocop -A && bin/ci`

2. **Fixture-driven OCR accuracy validation:**
   - Run each slice 0 fixture through the full pipeline (upload → job → draft).
   - Compare against annotated expected output in `manifest.yml`.
   - Record per-fixture results:

     | Fixture | Expected items | Extracted | Total match | Key found | Confidence | Pass |
     |---|---|---|---|---|---|---|
     | `clear_cupom.jpg` | 5 | 5 | ✓ | ✓ | high | ✓ |
     | `faded_cupom.jpg` | 5 | 3 | partial | ✓ (QR) | low | ✓ (QR win) |
     | `no_qr_cupom.jpg` | 5 | 4 | ✓ | ✗ | medium | ✓ |
     | `unreadable.jpg` | — | 0 | ✗ | ✗ | — | ✓ (safe fail) |
     | `scanned_danfe.pdf` | — | — | — | ✓ (key) | medium | ✓ |

3. **Manual testing on real devices:**
   - **Mobile (phone camera):**
     - Open fiscal import modal → select a photo of a printed cupom the user owns.
     - Verify the draft is saved with `processing` status and the inbox shows the
       spinner.
     - Wait for the job to complete; verify the inbox card updates to `ready` live.
     - Open the draft as a cash or card transaction; check confidence indicators.
     - Edit a low-confidence item, acknowledge any difference, save.
   - **Desktop:**
     - Upload a scanned DANFE PDF (image-only, no selectable text).
     - Verify fallback from `PdfKeyExtractor` to OCR path.
     - Review and save.
   - **Hybrid path:**
     - Upload a cupom photo with readable printed text. Verify OCR processes and,
       if a key is found, the structured lookup supplements the result.
   - **Failure paths:**
     - Upload an oversized image (> 10 MiB) — rejected at upload.
     - Upload an image with no recognizable receipt content — `failed` draft.
     - Retry a failed draft — re-processes.
     - Delete a processing draft — removed cleanly.
   - Record results for each test.

4. **Privacy verification:**
   - Grep application logs after an OCR import: confirm no raw OCR text, no
     personal identifiers, no image data in logs.
   - Confirm Tesseract runs only locally; no network calls during OCR processing.
   - Confirm raw OCR text is not stored in the database: only parsed fields
     (issuer, items, total) exist in the draft payload.

5. **Resource usage verification:**
   - Monitor VPS memory and CPU during OCR processing of the largest fixture.
   - Confirm the job does not hold memory after completion (temp files cleaned up).
   - Confirm SolidQueue processes the job without blocking other queued work.

6. **Documentation updates:**
   - Update `docs/sprints/5-naruto/naruto-08/01-product-and-data-contract.md`
     with completion status, resolved open decisions, and remaining limitations.
   - Update `SPRINT_5.md` with NARUTO-08 status.
   - Record the source matrix, accuracy results, and deferred families.

7. **Deployment checklist:**
   - `tesseract-ocr` and `tesseract-ocr-por` packages in the production container.
   - `poppler-utils` or `pdfium` for PDF-to-image rendering via vips.
   - Confirm OCR job processing does not block other SolidQueue workers beyond
     the configured timeout.
   - Confirm temp file cleanup under the application's tmp directory.

### Primary touchpoints
- `spec/services/ocr/`
- `spec/jobs/ocr_extraction_job_spec.rb`
- `spec/requests/fiscal_receipt_imports_spec.rb`
- `spec/requests/fiscal_receipt_drafts_spec.rb`
- `spec/features/`
- `docs/sprints/5-naruto/naruto-08/`
- `SPRINT_5.md`

### Acceptance criteria
- All automated specs pass. `bin/ci` is green.
- Each fixture in the corpus produces the expected result (extraction or safe
  failure).
- Manual testing on mobile and desktop produces correct, reviewable OCR drafts
  with live inbox status updates.
- No OCR text, personal data, or image content appears in application logs or
  database outside the parsed draft fields.
- VPS resource usage during OCR stays within acceptable bounds (no runaway memory
  or CPU).
- Documentation records the supported document families, accuracy expectations,
  deferred families, and known limitations.
- RuboCop reports 0 offenses.
