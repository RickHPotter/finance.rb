import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  close() {
    this.element.querySelector(":nth-child(2)").dispatchEvent(new CustomEvent("close"))
    this.element.classList.add("hidden")
  }
}
