import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["bar", "checkbox", "count", "action", "statusValue", "categoryValue", "entityValue"]

  connect() {
    this.selectionChanged()
    this.changeAction()
  }

  selectionChanged() {
    const selected = this.checkboxTargets.filter((checkbox) => checkbox.checked).length
    this.countTarget.textContent = selected
    this.barTarget.classList.toggle("hidden", selected === 0)
    this.barTarget.classList.toggle("flex", selected > 0)
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
