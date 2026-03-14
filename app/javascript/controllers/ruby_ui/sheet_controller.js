import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]

  connect() {
    this.ensureContent()
    this.renderedContent()?.classList.add("hidden")
  }

  open() {
    this.ensureContent()
    this.renderedContent()?.classList.remove("hidden")
  }

  ensureContent() {
    if (this.renderedContent()) return

    this.element.insertAdjacentHTML("beforeend", this.contentTarget.innerHTML)
  }

  renderedContent() {
    return this.element.querySelector(":scope > div[data-controller='ruby-ui--sheet-content']")
  }
}
