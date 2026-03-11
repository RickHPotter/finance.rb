import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["table", "row", "category", "entity", "checkbox", "bulkBar", "selectedCount"]

  connect() {
    this.initialise()
    this.syncBulkBars()
  }

  initialise() {
    document.addEventListener("dragover", (event) => {
      event.preventDefault()
    })

    document.addEventListener("drop", (event) => {
      const transactionId = event.dataTransfer.getData("text/plain")
      const monthBtn = event.target.closest("[data-month-year-selector-target='monthYear']")
      // TODO: implement dragging to another month, or maybe even to another card
      // implement also a toast with undo button and, obviously the undo functionality
    })
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
    const row = checkbox.closest("[data-datatable-target='row']")
    const monthGroup = checkbox.closest("[data-month-year-group]")
    if (!row || !monthGroup) return

    this.updateRowSelectionState(row, checkbox.checked)
    this.syncBulkBars()
  }

  toggleCardSelection(event) {
    if (event.target.closest("a, button, input, label, summary, details")) return

    const row = event.currentTarget
    const checkbox = row.querySelector("[data-datatable-target='checkbox']")
    if (!checkbox || checkbox.disabled) return

    checkbox.checked = !checkbox.checked
    this.updateRowSelectionState(row, checkbox.checked)
    this.syncBulkBars()
  }

  prepareBulkAction(event) {
    const selectedIds = this.selectedCheckboxes().map(checkbox => checkbox.value)

    this.element.querySelectorAll("[data-bulk-ids-input]").forEach(input => {
      input.value = selectedIds.join(",")
    })
  }

  syncBulkBars() {
    const selectedCount = this.selectedCheckboxes().length

    this.bulkBarTargets.forEach(bar => {
      bar.classList.toggle("hidden", selectedCount === 0)

      const countTarget = bar.querySelector("[data-datatable-target='selectedCount']")
      if (countTarget) countTarget.textContent = selectedCount
    })
  }

  selectedCheckboxes() {
    return this.checkboxTargets
      .filter(checkbox => checkbox.checked)
      .filter(checkbox => checkbox.closest("[data-datatable-target='row']")?.style.display !== "none")
  }

  selectedCheckboxesFor(monthGroup) {
    return Array.from(monthGroup.querySelectorAll("[data-datatable-target='checkbox']:checked"))
      .filter(checkbox => checkbox.closest("[data-datatable-target='row']")?.style.display !== "none")
  }

  updateRowSelectionState(row, selected) {
    if (!row) return

    row.classList.toggle("ring-2", selected)
    row.classList.toggle("ring-inset", selected)
    row.classList.toggle("ring-blue-600", selected)
    row.classList.toggle("z-10", selected)

    row.classList.toggle("!animate-none", selected)
  }
}
