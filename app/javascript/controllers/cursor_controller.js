import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.restoreCursor()
  }

  restoreCursor() {
    const position = this.element.value.length
    this.element.setSelectionRange(position, position)
  }
}
