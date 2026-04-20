import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    select: { type: Boolean, default: false }
  }

  connect() {
    this.focused = false
    this.focusWhenVisible = this.focusWhenVisible.bind(this)
    this.observeVisibilityChanges()
    requestAnimationFrame(() => {
      this.focusWhenVisible()
    })
  }

  disconnect() {
    this.observer?.disconnect()
  }

  focusWhenVisible() {
    if (this.focused) { return }
    if (this.element.disabled) { return }
    if (this.element.type === "hidden") { return }
    if (!this.element.checkVisibility()) { return }

    this.focused = true
    this.element.focus()
    if (this.selectValue) {
      this.element.select?.()
    }

    this.observer?.disconnect()
  }

  observeVisibilityChanges() {
    const root = this.element.parentElement?.closest("[id]") || this.element.parentElement
    if (!root) { return }

    this.observer = new MutationObserver(this.focusWhenVisible)
    this.observer.observe(root, {
      attributes: true,
      subtree: true,
      attributeFilter: ["class", "style", "aria-hidden"]
    })
  }
}
