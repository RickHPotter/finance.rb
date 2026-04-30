import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]
  static values = { portal: Boolean }

  connect() {
    this.sheetOwnerId = this.element.dataset.sheetOwnerId || crypto.randomUUID()
    this.element.dataset.sheetOwnerId = this.sheetOwnerId
    this.ensureContent()
    this.renderedContent()?.classList.add("hidden")
  }

  disconnect() {
    if (this.portalValue) {
      this.renderedContent()?.remove()
    }
  }

  open() {
    this.ensureContent()
    this.renderedContent()?.classList.remove("hidden")
  }

  ensureContent() {
    if (this.renderedContent()) return

    const content = this.contentTarget.content.firstElementChild.cloneNode(true)
    content.dataset.sheetOwnerId = this.sheetOwnerId

    if (this.portalValue) {
      this.portalHost().appendChild(content)
    } else {
      this.element.appendChild(content)
    }
  }

  portalHost() {
    return this.element.closest("form") || document.body
  }

  renderedContent() {
    if (this.portalValue) {
      return document.querySelector(`div[data-controller='ruby-ui--sheet-content'][data-sheet-owner-id='${this.sheetOwnerId}']`)
    }

    return this.element.querySelector(`:scope > div[data-controller='ruby-ui--sheet-content'][data-sheet-owner-id='${this.sheetOwnerId}']`)
  }
}
