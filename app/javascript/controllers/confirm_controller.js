import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]

  connect() {
    this.link = this.element.nextElementSibling
    if (this.link) {
      this.boundConfirm = this.confirm.bind(this)
      this.link.addEventListener("click", this.boundConfirm)
    }
  }

  disconnect() {
    if (this.link && this.boundConfirm) {
      this.link.removeEventListener("click", this.boundConfirm)
    }
  }

  confirm(event) {
    event.preventDefault()
    event.stopPropagation()
  }

  proceed() {
    this.link.removeEventListener("click", this.boundConfirm)
    this.link.click()
    this.link.addEventListener("click", this.boundConfirm)
  }
}
