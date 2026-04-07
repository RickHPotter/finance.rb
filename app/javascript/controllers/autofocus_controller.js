import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    select: { type: Boolean, default: false }
  }

  connect() {
    requestAnimationFrame(() => {
      if (this.element.disabled) { return }
      if (this.element.type === "hidden") { return }

      this.element.focus()
      if (this.selectValue) {
        this.element.select?.()
      }
    })
  }
}
