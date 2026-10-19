import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["bar", "checkbox", "row", "count", "action", "statusValue", "categoryValue", "entityValue"]

  connect() {
    this.selectionChanged()
    this.changeAction()
  }

  selectionChanged() {
    const selected = this.checkboxTargets.filter((checkbox) => checkbox.checked).length
    this.countTarget.textContent = selected
    this.barTarget.classList.toggle("hidden", selected === 0)
    this.barTarget.classList.toggle("flex", selected > 0)
    this.rowTargets.forEach((row) => {
      const checked = row.querySelector("[data-subscription-bulk-target='checkbox']")?.checked || false
      row.classList.toggle("ring-2", checked)
      row.classList.toggle("ring-inset", checked)
      row.classList.toggle("ring-blue-600", checked)
      row.classList.toggle("z-10", checked)
    })
  }

  clear() {
    this.checkboxTargets.forEach((checkbox) => { checkbox.checked = false })
    this.selectionChanged()
  }

  changeAction() {
    const action = this.actionTarget.value
    this.toggleValue(this.statusValueTarget, action === "status")
    this.toggleValue(this.categoryValueTarget, action === "replace_category")
    this.toggleValue(this.entityValueTarget, action === "replace_entity")
  }

  toggleValue(element, active) {
    element.disabled = !active
    element.required = active
    element.classList.toggle("hidden", !active)
  }
}
