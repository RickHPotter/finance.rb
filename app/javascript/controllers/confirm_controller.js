import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { linkId: String }

  connect() {
    if (this.element.parentElement !== document.body) {
      document.body.appendChild(this.element)
    }

    this.link = document.getElementById(this.linkIdValue)
    if (!this.link) return

    if (this.boundConfirm) {
      this.link.removeEventListener("click", this.boundConfirm)
    }

    this.boundConfirm = this.confirm.bind(this)
    this.link.addEventListener("click", this.boundConfirm)
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
    if (!this.link) return

    this.link.removeEventListener("click", this.boundConfirm)
    this.link.click()
    this.link.addEventListener("click", this.boundConfirm)
  }
}
