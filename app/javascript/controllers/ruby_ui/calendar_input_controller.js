import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="input"
export default class extends Controller {
  setValue(value) {
    if (this.element.value === value) return

    this.element.value = value
    this.element.dispatchEvent(new Event("input", { bubbles: true }))
    this.element.dispatchEvent(new Event("change", { bubbles: true }))
  }
}
