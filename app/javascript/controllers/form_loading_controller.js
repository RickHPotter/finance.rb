import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "skeleton"]
  static values = { preview: Boolean }

  connect() {
    this.syncPreview()
  }

  start(event) {
    if (!(event.target instanceof HTMLFormElement)) return
    if (!this.element.contains(event.target)) return

    this.contentTarget.classList.add("invisible", "pointer-events-none")
    this.skeletonTarget.classList.remove("hidden")
  }

  stop() {
    if (!this.hasContentTarget || !this.hasSkeletonTarget) return
    if (this.previewValue) return

    this.contentTarget.classList.remove("invisible", "pointer-events-none")
    this.skeletonTarget.classList.add("hidden")
  }

  togglePreview() {
    this.previewValue = !this.previewValue
    this.syncPreview()
  }

  syncPreview() {
    if (!this.hasContentTarget || !this.hasSkeletonTarget) return

    this.contentTarget.classList.toggle("invisible", this.previewValue)
    this.contentTarget.classList.toggle("pointer-events-none", this.previewValue)
    this.skeletonTarget.classList.toggle("hidden", !this.previewValue)
    this.skeletonTarget.setAttribute("aria-hidden", (!this.previewValue).toString())
  }
}
