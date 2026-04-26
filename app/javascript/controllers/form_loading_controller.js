import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "skeleton"]

  start(event) {
    if (!(event.target instanceof HTMLFormElement)) return
    if (!this.element.contains(event.target)) return

    this.contentTarget.classList.add("invisible", "pointer-events-none")
    this.skeletonTarget.classList.remove("hidden")
  }

  stop() {
    if (!this.hasContentTarget || !this.hasSkeletonTarget) return

    this.contentTarget.classList.remove("invisible", "pointer-events-none")
    this.skeletonTarget.classList.add("hidden")
  }
}
