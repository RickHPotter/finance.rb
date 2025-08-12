import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]

  initialize() {
    this.element.insertAdjacentHTML("beforeend", this.contentTarget.innerHTML)
    this.element.querySelector("[data-controller='ruby-ui--sheet-content']").classList.add("hidden")
  }

  open() {
    const existingSheetContent = this.element.querySelector("[data-controller='ruby-ui--sheet-content']")

    if (existingSheetContent) {
      existingSheetContent.classList.remove("hidden")
    } else {
      this.element.insertAdjacentHTML("beforeend", this.contentTarget.innerHTML)
    }
  }
}
