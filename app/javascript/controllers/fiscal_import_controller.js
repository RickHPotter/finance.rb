import { Controller } from "@hotwired/stimulus"
import { _applyMask, _removeMask } from "../utils/mask.js"

export default class extends Controller {
  static targets = ["file", "button", "status"]
  static values = { url: String, reviewMessage: String, replaceMessage: String }

  async import() {
    const file = this.fileTarget.files[0]
    if (!file) {
      this.showStatus("Choose an XML file first.", true)
      return
    }

    if (file.size > 10 * 1024 * 1024) {
      this.showStatus("The fiscal file must be 10 MB or smaller.", true)
      return
    }

    this.buttonTarget.disabled = true
    this.showStatus("Reading fiscal items...")

    try {
      const body = new FormData()
      body.append("file", file)
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: { "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content || "", Accept: "application/json" },
        body
      })
      const result = await response.json()
      if (!response.ok) throw new Error(result.error || "The receipt could not be imported.")
      if (this.hasExistingValues() && !window.confirm(this.replaceMessageValue)) return

      this.applyDraft(result.draft)
      this.stageAttachment(file)
      this.showStatus(this.reviewMessageValue.replace("%{count}", result.draft.items.length))
    } catch (error) {
      this.showStatus(error.message, true)
    } finally {
      this.buttonTarget.disabled = false
    }
  }

  hasExistingValues() {
    const description = this.parentDescriptionInput()?.value.trim()
    const price = _removeMask(this.parentPriceInput()?.value || "")
    const lineDescription = this.element.querySelector("[data-composite-transaction-target~='row'] input[name$='[description]']")?.value.trim()
    return Boolean(description || (price && parseInt(price, 10) !== 0) || lineDescription)
  }

  applyDraft(draft) {
    const splitTab = this.element.querySelector("[data-value='split']")
    const composite = this.application.getControllerForElementAndIdentifier(this.element, "composite-transaction")
    const priceMask = this.application.getControllerForElementAndIdentifier(this.element, "price-mask")
    if (!splitTab || splitTab.disabled || !composite || !priceMask) throw new Error("The split purchase form is unavailable.")

    splitTab.click()
    composite.clearAllRows()
    priceMask.setSignForSelector(".sign-based", "-")

    const description = this.parentDescriptionInput()
    if (description) description.value = draft.issuer || "Cupom fiscal"
    const parentPrice = this.parentPriceInput()
    parentPrice.value = _applyMask((-draft.total_cents).toString())
    parentPrice.dispatchEvent(new Event("input", { bubbles: true }))

    draft.items.forEach((item) => {
      composite.addRow()
      const row = composite.activeRows.at(-1)
      row.querySelector("input[name$='[description]']").value = item.description
      const price = row.querySelector("[data-composite-transaction-target~='itemPrice']")
      price.value = _applyMask((-item.price_cents).toString())
      price.dispatchEvent(new Event("input", { bubbles: true }))
    })
    composite.recalculate()
  }

  stageAttachment(file) {
    const signature = `${file.name}:${file.size}:${file.lastModified}`
    if (signature === this.lastStagedFile) return

    const upload = this.application.getControllerForElementAndIdentifier(this.element, "attachment-upload")
    upload?.processFiles([file])
    this.lastStagedFile = signature
  }

  parentDescriptionInput() {
    return this.element.querySelector("input[name$='[description]']:not([name*='[line_items_attributes]'])")
  }

  parentPriceInput() {
    return this.element.querySelector("#transaction_price")
  }

  showStatus(message, error = false) {
    this.statusTarget.textContent = message
    this.statusTarget.classList.toggle("text-rose-600", error)
    this.statusTarget.classList.toggle("text-emerald-700", !error)
  }
}
