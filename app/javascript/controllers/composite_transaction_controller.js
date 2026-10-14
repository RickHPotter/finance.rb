import { Controller } from "@hotwired/stimulus"
import { _applyMask, _removeMask } from "../utils/mask.js"

// Connects to data-controller="composite-transaction"
export default class extends Controller {
  static values = {
    composite: Boolean
  }

  static targets = [
    "splitToggle",
    "container",
    "headerAllocations",
    "allocationsContainer",
    "parentPrice",
    "itemsList",
    "template",
    "row",
    "itemPrice",
    "parentTotal",
    "allocatedSum",
    "differenceBadge",
    "differenceLabel"
  ]

  connect() {
    this.syncInitialState()
    this.recalculate()
  }

  syncInitialState() {
    const isSplit = this.hasSplitToggleTarget ? this.splitToggleTarget.checked : this.compositeValue
    this.applySplitVisibility(isSplit)
  }

  toggleSplit(event) {
    const isSplit = event.target.checked
    this.applySplitVisibility(isSplit)

    if (isSplit) {
      if (this.activeRows.length === 0) this.addRow()
    } else {
      this.clearAllRows()
    }

    this.syncSplitHiddenInput(isSplit)
    this.recalculate()
  }

  tabChanged(event) {
    const isSplit = event.currentTarget.dataset.value === "split"
    this.applySplitVisibility(isSplit)

    if (isSplit) {
      if (this.activeRows.length === 0) this.addRow()
    } else {
      this.clearAllRows()
    }

    this.syncSplitHiddenInput(isSplit)
    this.recalculate()
  }

  applySplitVisibility(isSplit) {
    if (this.hasHeaderAllocationsTarget) {
      this.headerAllocationsTarget.classList.toggle("pointer-events-none", isSplit)
      this.headerAllocationsTarget.classList.toggle("opacity-50", isSplit)
      this.headerAllocationsTarget.querySelectorAll("button, input").forEach(el => {
        el.disabled = isSplit
      })
    }

    if (this.hasAllocationsContainerTarget) {
      this.allocationsContainerTarget.classList.toggle("pointer-events-none", isSplit)
      this.allocationsContainerTarget.classList.toggle("opacity-50", isSplit)
      this.allocationsContainerTarget.querySelectorAll("button, input").forEach(el => {
        el.disabled = isSplit
      })
    }
  }

  syncSplitHiddenInput(isSplit) {
    const input = this.element.querySelector("input[name*='[split_purchase]']")
    if (input) input.value = isSplit ? "1" : "0"
  }

  clearAllRows() {
    this.rowTargets.forEach(row => {
      if (row.dataset.persisted === "true") {
        const destroyInput = row.querySelector("input[name*='[_destroy]']")
        if (destroyInput) destroyInput.value = "1"
        row.classList.add("hidden")
        row.style.display = "none"
      } else {
        row.remove()
      }
    })
  }

  addRow(event) {
    if (event) event.preventDefault()
    if (!this.hasTemplateTarget || !this.hasItemsListTarget) return

    const timestamp = new Date().getTime().toString() + Math.floor(Math.random() * 1000).toString()
    const content = this.templateTarget.innerHTML.replace(/NEW_LINE_ITEM/gi, timestamp)
    this.itemsListTarget.insertAdjacentHTML("beforeend", content)

    const entityModalTemplate = this.element.querySelector("[data-composite-entity-modal-target~='template']")
    const entityModalGroups = this.element.querySelector("[data-composite-entity-modal-target~='groups']")
    if (entityModalTemplate && entityModalGroups) {
      entityModalGroups.insertAdjacentHTML("beforeend", entityModalTemplate.innerHTML.replace(/NEW_LINE_ITEM/gi, timestamp))
    }

    this.syncRowSign()
    this.recalculate()
  }

  removeRow(event) {
    if (event) event.preventDefault()

    const row = event.target.closest("[data-composite-transaction-target~='row']")
    if (!row) return

    if (row.dataset.persisted === "true") {
      const destroyInput = row.querySelector("input[name*='[_destroy]']")
      if (destroyInput) destroyInput.value = "1"
      row.classList.add("hidden")
      row.style.display = "none"
    } else {
      row.remove()
    }

    this.recalculate()
  }

  syncRowSign() {
    const sign = this.parentSign
    this.itemPriceTargets.forEach(input => {
      input.dataset.sign = sign
    })
  }

  get parentSign() {
    const parentInput = this.resolveParentPriceInput()
    if (parentInput && parentInput.dataset.sign) {
      return parentInput.dataset.sign
    }
    return "-"
  }

  resolveParentPriceInput() {
    if (this.hasParentPriceTarget) return this.parentPriceTarget
    return document.getElementById("transaction_price")
  }

  get activeRows() {
    return this.rowTargets.filter(row => {
      if (row.classList.contains("hidden") || row.style.display === "none") return false
      const destroyInput = row.querySelector("input[name*='[_destroy]']")
      return !(destroyInput && destroyInput.value === "1")
    })
  }

  parseCents(val, sign) {
    const cleaned = _removeMask(val || "")
    let cents = parseInt(cleaned, 10)
    if (isNaN(cents)) return 0

    if (sign === "-" && cents > 0) {
      cents = -cents
    }
    return cents
  }

  formatCurrency(cents) {
    return _applyMask(cents.toString())
  }

  recalculate() {
    const parentInput = this.resolveParentPriceInput()
    const parentVal = parentInput ? parentInput.value : "0"
    const sign = parentInput?.dataset.sign
    const parentCents = this.parseCents(parentVal, sign)

    this.syncRowSign()

    let allocatedCents = 0
    this.activeRows.forEach(row => {
      const priceInput = row.querySelector("[data-composite-transaction-target~='itemPrice']")
      if (priceInput) {
        const itemVal = priceInput.value
        allocatedCents += this.parseCents(itemVal, priceInput.dataset.sign || sign)
      }
    })

    const diff = parentCents - allocatedCents

    if (this.hasParentTotalTarget) {
      this.parentTotalTarget.textContent = this.formatCurrency(parentCents)
    }

    if (this.hasAllocatedSumTarget) {
      this.allocatedSumTarget.textContent = this.formatCurrency(allocatedCents)
    }

    if (this.hasDifferenceBadgeTarget) {
      this.updateDifferenceBadge(diff, parentCents, this.activeRows.length)
    }
  }

  updateDifferenceBadge(diff, parentCents, activeRowCount) {
    const badge = this.differenceBadgeTarget
    const label = this.hasDifferenceLabelTarget ? this.differenceLabelTarget : null
    const balancedText = badge.dataset.balancedText || "Balanced"
    const minItemsText = badge.dataset.minItemsText || "Min 2 items needed"
    const remainingText = badge.dataset.remainingText || "Remaining:"
    const overAllocatedText = badge.dataset.overAllocatedText || "Over by:"

    badge.className = "font-semibold text-gray-800 font-graduate dark:text-slate-200 dark:font-mono"

    if (diff === 0 && activeRowCount >= 2 && parentCents !== 0) {
      if (label) {
        label.textContent = ""
        label.classList.add("hidden")
      }
      badge.textContent = balancedText
    } else if (diff === 0 && activeRowCount < 2) {
      if (label) {
        label.textContent = ""
        label.classList.add("hidden")
      }
      badge.textContent = minItemsText
    } else if ((parentCents >= 0 && diff > 0) || (parentCents < 0 && diff < 0)) {
      if (label) {
        label.textContent = remainingText
        label.classList.remove("hidden")
      }
      badge.textContent = this.formatCurrency(Math.abs(diff))
    } else {
      if (label) {
        label.textContent = overAllocatedText
        label.classList.remove("hidden")
      }
      badge.textContent = this.formatCurrency(Math.abs(diff))
    }
  }
}
