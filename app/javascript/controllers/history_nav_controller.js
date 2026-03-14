import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["back", "forward"]

  connect() {
    this.refresh = this.refresh.bind(this)

    this.refresh()
    window.addEventListener("popstate", this.refresh)
    document.addEventListener("turbo:load", this.refresh)
    document.addEventListener("turbo:frame-load", this.refresh)
  }

  disconnect() {
    window.removeEventListener("popstate", this.refresh)
    document.removeEventListener("turbo:load", this.refresh)
    document.removeEventListener("turbo:frame-load", this.refresh)
  }

  back(event) {
    event.preventDefault()
    if (this.backTarget.disabled) return

    window.history.back()
  }

  forward(event) {
    event.preventDefault()
    if (this.forwardTarget.disabled) return

    window.history.forward()
  }

  refresh() {
    const canGoBack = window.navigation?.canGoBack ?? window.history.length > 1
    const canGoForward = window.navigation?.canGoForward ?? true

    this.setButtonState(this.backTarget, canGoBack)
    this.setButtonState(this.forwardTarget, canGoForward)
  }

  setButtonState(button, enabled) {
    button.disabled = !enabled
    button.classList.toggle("opacity-40", !enabled)
    button.classList.toggle("pointer-events-none", !enabled)
  }
}
