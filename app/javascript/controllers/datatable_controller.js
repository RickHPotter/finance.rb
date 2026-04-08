import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["row", "checkbox", "bulkBar", "selectedCount", "selectedTotal", "selectionHint", "bulkActionButton", "selectPageButton"]
  static values = { locale: String }

  connect() {
    this.onDocumentDragOver = this.onDocumentDragOver || ((event) => {
      event.preventDefault()
    })

    this.onDocumentDrop = this.onDocumentDrop || ((event) => {
      const transactionId = event.dataTransfer.getData("text/plain")
      const monthBtn = event.target.closest("[data-month-year-selector-target='monthYear']")
      // TODO: implement dragging to another month, or maybe even to another card
      // implement also a toast with undo button and, obviously the undo functionality
    })
    this.onDocumentKeyDown = this.onDocumentKeyDown || ((event) => {
      if (event.key === "Shift") this.shiftPressed = true
    })
    this.onDocumentKeyUp = this.onDocumentKeyUp || ((event) => {
      if (event.key === "Shift") this.shiftPressed = false
    })

    this.lastSelectedCheckbox = null
    this.shiftPressed = false
    this.hideBarTimeout = null
    this.hideBarTransitionTimeout = null
    this.initialise()
    this.syncBulkBars()
  }

  disconnect() {
    document.removeEventListener("dragover", this.onDocumentDragOver)
    document.removeEventListener("drop", this.onDocumentDrop)
    document.removeEventListener("keydown", this.onDocumentKeyDown)
    document.removeEventListener("keyup", this.onDocumentKeyUp)
    clearTimeout(this.hideBarTimeout)
    clearTimeout(this.hideBarTransitionTimeout)
  }

  initialise() {
    document.removeEventListener("dragover", this.onDocumentDragOver)
    document.removeEventListener("drop", this.onDocumentDrop)
    document.removeEventListener("keydown", this.onDocumentKeyDown)
    document.removeEventListener("keyup", this.onDocumentKeyUp)

    document.addEventListener("dragover", this.onDocumentDragOver)
    document.addEventListener("drop", this.onDocumentDrop)
    document.addEventListener("keydown", this.onDocumentKeyDown)
    document.addEventListener("keyup", this.onDocumentKeyUp)
  }

  filter(event) {
    const searchTerm = event.target.value.toLowerCase()
    this.rowTargets.forEach(row => {
      row.style.display = row.innerText.toLowerCase().includes(searchTerm) ? "" : "none"

      const checkbox = row.querySelector("[data-datatable-target='checkbox']")
      if (checkbox && row.style.display === "none" && checkbox.checked) {
        checkbox.checked = false
        this.updateRowSelectionState(row, false)
      }
    })

    this.syncBulkBars()
  }

  start(event) {
    event.dataTransfer.setData("text/plain", event.target.dataset.id)
    event.target.classList.add("opacity-50")
  }

  activate(event) {
    event.preventDefault()
  }

  drop(event) {
    event.preventDefault()
    event.target.classList.remove("opacity-50")
  }

  toggleSelection(event) {
    const checkbox = event.currentTarget
    event.stopPropagation()
    this.applySelection(checkbox, checkbox.checked, { shiftKey: event.shiftKey || this.shiftPressed })
  }

  preventRangeSelection(event) {
    if (!(event.shiftKey || this.shiftPressed)) return

    event.preventDefault()
    this.clearTextSelection()
  }

  toggleCardSelection(event) {
    if (event.target.closest("a, button, input, label, summary, details")) return

    if (event.shiftKey || this.shiftPressed) {
      event.preventDefault()
    }

    const row = event.currentTarget
    const checkbox = row.querySelector("[data-datatable-target='checkbox']")
    if (!checkbox || checkbox.disabled) return

    checkbox.checked = !checkbox.checked
    this.applySelection(checkbox, checkbox.checked, { shiftKey: event.shiftKey || this.shiftPressed })
  }

  prepareBulkAction(event) {
    const kind = event.currentTarget.dataset.bulkIdsKind || "installment"
    const selectedIds = this.selectedIds(kind)

    this.element.querySelectorAll("[data-bulk-ids-input]").forEach(input => {
      if ((input.dataset.bulkIdsKind || "installment") !== kind) return
      input.value = selectedIds.join(",")
    })
  }

  syncBulkBars() {
    const selected = this.selectedCheckboxes()
    const selectedCount = selected.length
    const totalCents = selected.reduce((sum, checkbox) => sum + this.priceFromCheckbox(checkbox), 0)
    const hint = this.syncActionButtons(selected)

    this.syncBulkBarVisibility(selectedCount)

    this.selectedCountTargets.forEach((target) => {
      target.textContent = selectedCount
    })

    this.selectedTotalTargets.forEach((target) => {
      target.textContent = this.formatCurrency(totalCents)
    })

    this.selectionHintTargets.forEach((target) => {
      target.textContent = hint
      target.classList.toggle("invisible", hint.length === 0)
    })

    this.selectPageButtonTargets.forEach((button) => {
      button.disabled = this.visibleCheckboxes().length === 0
    })
  }

  selectedCheckboxes() {
    return this.visibleCheckboxes().filter(checkbox => checkbox.checked)
  }

  selectedCheckboxesFor(monthGroup) {
    return Array.from(monthGroup.querySelectorAll("[data-datatable-target='checkbox']:checked"))
      .filter(checkbox => this.rowVisible(checkbox.closest("[data-datatable-target='row']")))
  }

  updateRowSelectionState(row, selected) {
    if (!row) return

    row.classList.toggle("ring-2", selected)
    row.classList.toggle("ring-inset", selected)
    row.classList.toggle("ring-blue-600", selected)
    row.classList.toggle("z-10", selected)

    row.classList.toggle("!animate-none", selected)
  }

  togglePageSelection() {
    const visibleCheckboxes = this.visibleCheckboxes()
    if (visibleCheckboxes.length === 0) return

    const shouldSelect = visibleCheckboxes.some((checkbox) => !checkbox.checked)

    visibleCheckboxes.forEach((checkbox) => {
      checkbox.checked = shouldSelect
      this.updateRowSelectionState(checkbox.closest("[data-datatable-target='row']"), shouldSelect)
    })

    this.lastSelectedCheckbox = visibleCheckboxes.at(-1) || null
    this.syncBulkBars()
  }

  applySelection(checkbox, checked, { shiftKey = false } = {}) {
    const visibleCheckboxes = this.visibleCheckboxes()
    const currentIndex = visibleCheckboxes.indexOf(checkbox)
    const anchorIndex = visibleCheckboxes.indexOf(this.lastSelectedCheckbox)

    if (shiftKey && currentIndex !== -1 && anchorIndex !== -1) {
      const start = Math.min(anchorIndex, currentIndex)
      const finish = Math.max(anchorIndex, currentIndex)

      visibleCheckboxes.slice(start, finish + 1).forEach((candidate) => {
        candidate.checked = checked
        this.updateRowSelectionState(candidate.closest("[data-datatable-target='row']"), checked)
      })
    } else {
      this.updateRowSelectionState(checkbox.closest("[data-datatable-target='row']"), checked)
    }

    this.lastSelectedCheckbox = checkbox
    this.clearTextSelection()
    this.syncBulkBars()
  }

  visibleCheckboxes() {
    return this.checkboxTargets.filter((checkbox) => this.rowVisible(checkbox.closest("[data-datatable-target='row']")))
  }

  rowVisible(row) {
    return row && row.style.display !== "none"
  }

  selectedIds(kind) {
    const values = this.selectedCheckboxes().map((checkbox) => {
      if (kind === "record") return checkbox.dataset.bulkRecordId

      return checkbox.value
    }).filter(Boolean)

    return [...new Set(values)]
  }

  syncActionButtons(selected) {
    let hint = ""

    this.bulkActionButtonTargets.forEach((button) => {
      const baseDisabled = this.datasetBoolean(button.dataset.bulkBaseDisabled)
      const actionName = button.dataset.bulkActionName
      let disabled = baseDisabled
      let reason = ""

      if (baseDisabled) {
        reason = button.dataset.bulkBaseDisabledReason || ""
      } else if (actionName && selected.length === 0) {
        disabled = true
      } else if (actionName && !this.selectionEligibleFor(actionName, selected)) {
        disabled = true
        reason = button.dataset.bulkDisabledReason || ""
      }

      button.toggleAttribute("disabled", disabled)
      button.disabled = disabled

      if (!hint && reason.length > 0) hint = reason
    })

    return hint
  }

  selectionEligibleFor(actionName, selected) {
    switch (actionName) {
      case "pay":
        return selected.every((checkbox) => this.datasetBoolean(checkbox.dataset.bulkPayEligible))
      case "transfer":
        return selected.every((checkbox) => this.datasetBoolean(checkbox.dataset.bulkTransferEligible))
      case "subscription":
        return selected.every((checkbox) => this.datasetBoolean(checkbox.dataset.bulkSubscriptionEligible))
      default:
        return true
    }
  }

  priceFromCheckbox(checkbox) {
    return parseInt(checkbox.dataset.bulkPriceCents || "0", 10)
  }

  formatCurrency(cents) {
    const locale = this.hasLocaleValue ? this.localeValue : (document.documentElement.lang || "en")

    return new Intl.NumberFormat(locale, {
      style: "currency",
      currency: "BRL"
    }).format(cents / 100)
  }

  clearTextSelection() {
    window.getSelection?.()?.removeAllRanges()
  }

  datasetBoolean(value) {
    return ["1", "true", "yes", "on"].includes(String(value || "").toLowerCase())
  }

  syncBulkBarVisibility(selectedCount) {
    if (selectedCount > 0) {
      this.showBulkBars()
    } else {
      this.scheduleBulkBarsHide()
    }
  }

  showBulkBars() {
    clearTimeout(this.hideBarTimeout)
    clearTimeout(this.hideBarTransitionTimeout)

    this.bulkBarTargets.forEach((bar) => {
      bar.classList.remove("hidden")

      requestAnimationFrame(() => {
        bar.classList.remove("opacity-0", "pointer-events-none")
      })
    })
  }

  scheduleBulkBarsHide() {
    clearTimeout(this.hideBarTimeout)
    clearTimeout(this.hideBarTransitionTimeout)

    this.hideBarTimeout = setTimeout(() => {
      this.bulkBarTargets.forEach((bar) => {
        bar.classList.add("opacity-0", "pointer-events-none")
      })

      this.hideBarTransitionTimeout = setTimeout(() => {
        this.bulkBarTargets.forEach((bar) => {
          bar.classList.add("hidden")
        })
      }, 300)
    }, 2000)
  }
}
