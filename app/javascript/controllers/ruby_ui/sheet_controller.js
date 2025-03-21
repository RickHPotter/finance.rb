import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]

  open() {
    this.element.insertAdjacentHTML("beforeend", this.contentTarget.innerHTML)
  }
}
