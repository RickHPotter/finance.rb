# NARUTO-03 Transaction Attachments: Implementation Slices

## Delivery Strategy

Implement attachments from the model outward. Each slice delivers a verifiable, tested
capability. The test suite must pass and RuboCop must remain clean after every slice.

No database migration is required: `active_storage_attachments` and `active_storage_blobs`
already exist in the schema.

---

## Slice 1: Gem, Model Declarations & Validators

### Goal

Add `active_storage_validations` gem, declare `has_many_attached :receipts` on all three
models, and attach content-type, size, and count validators.

### Detailed Steps

1. **Gemfile** (`Gemfile`):
   - Add `gem "active_storage_validations"`.
   - Run `bundle install`.

2. **`CashTransaction` model** (`app/models/cash_transaction.rb`):
   - Under `# @relationships`:
     ```ruby
     has_many_attached :receipts
     ```
   - Under `# @validations`:
     ```ruby
     validates :receipts,
       content_type: %w[application/pdf image/jpeg image/png image/heic application/xml text/xml application/zip],
       size: { max: 10.megabytes },
       limit: { max: 5 }
     ```

3. **`CardTransaction` model** (`app/models/card_transaction.rb`):
   - Same `has_many_attached` and `validates` declarations as `CashTransaction`.

4. **`LineItem` model** (`app/models/line_item.rb`):
   - `has_many_attached :receipts` only — **no validator yet** (no upload UI this sprint;
     validators are added when the UI is exposed in Layer 2).

5. **Model Specs**:
   - `spec/models/cash_transaction_spec.rb`:
     - Attaching a valid PDF passes validation.
     - Attaching a disallowed type (e.g. `.exe`) fails with a content-type error.
     - Attaching a file over 10 MB fails with a size error.
     - Attaching 6 files fails with a count error.
   - `spec/models/card_transaction_spec.rb`:
     - Same four scenarios.

### Primary Touchpoints

- `Gemfile`
- `app/models/cash_transaction.rb`
- `app/models/card_transaction.rb`
- `app/models/line_item.rb`
- `spec/models/cash_transaction_spec.rb`
- `spec/models/card_transaction_spec.rb`

### Acceptance Criteria

- `bundle exec rails c` shows `CashTransaction.reflect_on_attachment(:receipts)` returning
  the attachment reflection.
- Model validations reject disallowed types, oversized files, and more than 5 files.
- All model specs pass.

---

## Slice 2: Controller Params

### Goal

Permit `receipts: []` in the strong params for `CashTransactionsController` and
`CardTransactionsController` so file submissions reach the model.

### Detailed Steps

1. **`CashTransactionsController`** (`app/controllers/cash_transactions_controller.rb`):
   - Find the `cash_transaction_params` private method.
   - Append `receipts: []` to the `permit(...)` call.

2. **`CardTransactionsController`** (`app/controllers/card_transactions_controller.rb`):
   - Same change in `card_transaction_params`.

### Primary Touchpoints

- `app/controllers/cash_transactions_controller.rb`
- `app/controllers/card_transactions_controller.rb`

### Acceptance Criteria

- Submitting a form with an attached file does not raise an `ActionController::UnpermittedParameters`
  error.

---

## Slice 3: Stimulus Upload Controller & Shared Upload Component

### Goal

Build the client-side upload experience: a Stimulus controller that uses the
`@rails/activestorage` `DirectUpload` API to upload files directly to ActiveStorage with
per-file progress feedback, and a shared Phlex component that renders the "Attachments"
section in both the cash and card transaction forms.

### Detailed Steps

1. **Stimulus controller** (`app/javascript/controllers/attachment_upload_controller.js`):
   - Targets: `fileInput`, `fileList`, `template`.
   - On `fileInput` change: for each selected `File`, create a `DirectUpload` instance
     pointing at `/rails/active_storage/direct_uploads`.
   - `upload.create(callback)`: on progress event, update a per-file progress bar in `fileList`.
   - On success: append a hidden `<input name="cash_transaction[receipts][]" type="hidden"
     value="<signed_blob_id>">` to the form and render the preview item (thumbnail or icon).
   - On error: render an error state on that item.
   - Remove action: clicking the remove button on a pending file removes the hidden input and
     removes the list item from `fileList`.
   - Register controller in `app/javascript/controllers/index.js`.

2. **Shared upload Phlex component** (`app/components/transaction_receipts_upload_component.rb`):
   - Accepts `form:` (the Phlex form builder) and `record:` (the transaction).
   - Renders:
     - A labelled section heading ("Attachments" / "Anexos").
     - A drag-and-drop file picker (file input with `multiple: true`,
       `data: { direct_upload_url: rails_direct_uploads_url }`, and Stimulus action wiring).
     - An existing-files list for already-persisted attachments (filename + download link +
       delete button; delete wired to `AttachmentsController` via a Turbo-method DELETE link).
     - A pending-files list (populated by the Stimulus controller for newly selected files, not
       yet submitted).
     - A per-file progress bar template (hidden; cloned by the Stimulus controller per upload).
   - Hint text: "PDF, JPEG, PNG, HEIC, XML, ZIP — max 10 MB each, up to 5 files."

3. **Cash transaction form** (`app/views/cash_transactions/form.rb`):
   - After the main fields section, call the shared component:
     ```ruby
     render Components::TransactionReceiptsUploadComponent.new(form: f, record: cash_transaction)
     ```

4. **Card transaction form** (`app/views/card_transactions/form.rb`):
   - Same call with the card transaction record.

5. **Locale keys** (`config/locales/views/transactions.yml` or equivalent):
   - `attachments.section_title`, `attachments.hint`, `attachments.add_files`,
     `attachments.remove`, `attachments.download`.
   - Add `en` and `pt-BR` entries.

### Primary Touchpoints

- `app/javascript/controllers/attachment_upload_controller.js`
- `app/javascript/controllers/index.js`
- `app/components/transaction_receipts_upload_component.rb`
- `app/views/cash_transactions/form.rb`
- `app/views/card_transactions/form.rb`
- `config/locales/` (attachment keys)

### Acceptance Criteria

- Opening the cash or card transaction new/edit form shows the "Attachments" section.
- Selecting files triggers per-file progress bars; on completion the files appear in the
  pending list with previews (thumbnail for images, generic icon for PDF/XML).
- Removing a pending file before form submit removes it from the list.
- Submitting the form with valid files attaches them to the transaction.
- Already-persisted attachments on the edit form show filenames with download and delete links.

---

## Slice 4: Paperclip Badge on Index Rows

### Goal

Show a small paperclip icon on transaction index rows that have at least one receipt attached,
so users can quickly see which records have documentary evidence.

### Detailed Steps

1. **Cash transaction index** (`app/views/cash_transactions/month_year.rb`):
   - Locate the per-row badge/icon area.
   - Add a conditional paperclip SVG icon when `cash_transaction.receipts.attached?`.
   - Ensure the index query eager-loads the `receipts_attachments` association to avoid N+1:
     ```ruby
     .with_attached_receipts
     ```
     Add this scope call in `CashTransactionsController#index` (or wherever the relation is
     assembled) alongside any existing eager loads.

2. **Card transaction index** (`app/views/card_transactions/month_year.rb`):
   - Same treatment: conditional paperclip icon when `.receipts.attached?`.
   - Add `.with_attached_receipts` to the card transactions query.

### Primary Touchpoints

- `app/views/cash_transactions/month_year.rb`
- `app/views/card_transactions/month_year.rb`
- `app/controllers/cash_transactions_controller.rb` (eager load)
- `app/controllers/card_transactions_controller.rb` (eager load)

### Acceptance Criteria

- A transaction row with receipts shows the paperclip icon.
- A transaction row without receipts shows no icon.
- No N+1 queries introduced (confirm with `bullet` or query log).

---

## Slice 5: Attachment List on Show Pages & Shared Delete Controller

### Goal

Display the list of persisted attachments on transaction show pages (filename, download link,
delete button). Implement the shared `AttachmentsController` for `DELETE /attachments/:blob_signed_id`
that purges the blob and records the deletion in the parent transaction's audit metadata.

### Detailed Steps

1. **Route** (`config/routes.rb`):
   ```ruby
   resource :attachments, only: [] do
     delete ":blob_signed_id", action: :destroy, on: :collection, as: :attachment
   end
   ```
   Resulting path helper: `attachment_path(blob_signed_id:)` → `DELETE /attachments/:blob_signed_id`.

2. **`AttachmentsController`** (`app/controllers/attachments_controller.rb`):
   - `before_action :authenticate_user!` (or equivalent auth guard).
   - `destroy` action:
     - Find `ActiveStorage::Blob` by `ActiveStorage::Blob.find_signed!(params[:blob_signed_id])`.
     - Find the `ActiveStorage::Attachment` for that blob.
     - Locate the parent record through `attachment.record` (polymorphic).
     - Authorise: `attachment.record.user == current_user` (or equivalent ownership check).
     - Purge the blob: `attachment.purge`.
     - Touch the parent record to trigger a new `AuditVersion` entry, then append
       `{ attachments_deleted: [blob_key] }` to that version's metadata.
     - Respond with a Turbo Stream that removes the attachment row from the show page list.

3. **Shared attachment-list Phlex component**
   (`app/components/transaction_receipts_list_component.rb`):
   - Accepts `record:` (the transaction).
   - Renders a `section_card`-style block titled "Attachments".
   - Lists each `record.receipts` with:
     - Filename (`blob.filename`).
     - File size (humanised).
     - Download link: `rails_blob_path(receipt, disposition: "attachment")`.
     - Delete button: Turbo-method DELETE to `attachment_path(blob_signed_id: receipt.signed_id)`,
       with a `data-turbo-confirm` prompt.
   - Shows a placeholder "No attachments" when `record.receipts.empty?`.

4. **Cash transaction show page** (`app/views/cash_transactions/show.rb`):
   - Add a call to `render Components::TransactionReceiptsListComponent.new(record: cash_transaction)`
     inside `view_template`, after the existing `links_section` call.

5. **Card transaction show page** (`app/views/card_transactions/show.rb`):
   - Same call with the card transaction record.

### Primary Touchpoints

- `config/routes.rb`
- `app/controllers/attachments_controller.rb`
- `app/components/transaction_receipts_list_component.rb`
- `app/views/cash_transactions/show.rb`
- `app/views/card_transactions/show.rb`

### Acceptance Criteria

- Transaction show page displays attached filenames with download and delete links.
- Clicking delete removes the attachment from the server and the Turbo Stream removes the row
  from the show page without a full reload.
- Attempting to delete an attachment belonging to another user returns `403`.
- Deletion appends `{ attachments_deleted: [blob_key] }` to the parent transaction's
  audit metadata.

---

## Slice 6: Specs

### Goal

Achieve full spec coverage: model validation coverage on all three models and request
coverage for upload, download, and delete on both cash and card transactions.

### Detailed Steps

1. **Model specs**:
   - `spec/models/cash_transaction_spec.rb` (carried over from Slice 1 — ensure complete):
     - Valid attachment passes.
     - Disallowed MIME type fails with content-type error.
     - File > 10 MB fails with size error.
     - 6th file fails with count error.
   - `spec/models/card_transaction_spec.rb`: same four scenarios.
   - `spec/models/line_item_spec.rb`: assert `has_many_attached :receipts` is declared
     (reflection present); no validators yet.

2. **Request specs — cash transactions** (`spec/requests/cash_transactions_spec.rb`):
   - `PATCH /cash_transactions/:id` with `receipts: [valid_file]` — attaches the file.
   - `GET /rails/active_storage/blobs/:signed_id/*filename` — downloads successfully with
     content-disposition `attachment`.
   - `DELETE /attachments/:blob_signed_id` with valid ownership — purges blob, returns Turbo
     Stream response, blob no longer exists.
   - `DELETE /attachments/:blob_signed_id` belonging to another user — returns 403.

3. **Request specs — card transactions** (`spec/requests/card_transactions_spec.rb`):
   - Same upload and delete scenarios.

### Primary Touchpoints

- `spec/models/cash_transaction_spec.rb`
- `spec/models/card_transaction_spec.rb`
- `spec/models/line_item_spec.rb`
- `spec/requests/cash_transactions_spec.rb`
- `spec/requests/card_transactions_spec.rb`

### Acceptance Criteria

- 0 RuboCop offenses.
- All new specs pass.
- No regressions in existing specs.

---

## Slice 7: Regression Verification & Code Cleanliness

### Goal

Run full test suite, RuboCop, and CI sequence to confirm zero regressions.

### Detailed Steps

1. Run `bin/rubocop -A`.
2. Run targeted spec groups:
   ```
   bin/rspec spec/models/cash_transaction_spec.rb
   bin/rspec spec/models/card_transaction_spec.rb
   bin/rspec spec/models/line_item_spec.rb
   bin/rspec spec/requests/cash_transactions_spec.rb
   bin/rspec spec/requests/card_transactions_spec.rb
   ```
3. Run `bin/ci`.

### Acceptance Criteria

- 0 RuboCop offenses.
- All tests pass cleanly.
