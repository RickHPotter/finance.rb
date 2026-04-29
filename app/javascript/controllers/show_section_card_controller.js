import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "icon", "button"]
  static values = { open: { type: Boolean, default: true } }

  connect() {
    this.sync()
  }

  toggle() {
    this.openValue = !this.openValue
    this.sync()
  }

  sync() {
    const expanded = this.openValue

    this.contentTarget.classList.toggle("hidden", !expanded)
    this.buttonTarget.setAttribute("aria-expanded", expanded ? "true" : "false")
    this.iconTarget.textContent = expanded ? "−" : "+"
  }
}
