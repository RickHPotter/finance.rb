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
    "differenceBadge"
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
      if (this.activeRows.length < 2) {
        while (this.activeRows.length < 2) {
          this.addRow()
        }
      }
    } else {
      this.clearAllRows()
    }

    this.recalculate()
  }

  applySplitVisibility(isSplit) {
    if (this.hasContainerTarget) {
      this.containerTarget.classList.toggle("hidden", !isSplit)
    }

    if (this.hasHeaderAllocationsTarget) {
      this.headerAllocationsTarget.classList.toggle("hidden", isSplit)
    }

    if (this.hasAllocationsContainerTarget) {
      this.allocationsContainerTarget.classList.toggle("hidden", isSplit)
    }
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
    const balancedText = badge.dataset.balancedText || "Balanced"
    const minItemsText = badge.dataset.minItemsText || "Min 2 items needed"
    const remainingText = badge.dataset.remainingText || "Remaining:"
    const overAllocatedText = badge.dataset.overAllocatedText || "Over by:"

    badge.className = "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold"

    if (diff === 0 && activeRowCount >= 2 && parentCents !== 0) {
      badge.textContent = balancedText
      badge.classList.add("bg-emerald-500/20", "text-emerald-400", "border", "border-emerald-500/30")
    } else if (diff === 0 && activeRowCount < 2) {
      badge.textContent = minItemsText
      badge.classList.add("bg-amber-500/20", "text-amber-400", "border", "border-amber-500/30")
    } else if ((parentCents >= 0 && diff > 0) || (parentCents < 0 && diff < 0)) {
      badge.textContent = `${remainingText} ${this.formatCurrency(Math.abs(diff))}`
      badge.classList.add("bg-rose-500/20", "text-rose-400", "border", "border-rose-500/30")
    } else {
      badge.textContent = `${overAllocatedText} ${this.formatCurrency(Math.abs(diff))}`
      badge.classList.add("bg-amber-500/20", "text-amber-400", "border", "border-amber-500/30")
    }
  }
}
