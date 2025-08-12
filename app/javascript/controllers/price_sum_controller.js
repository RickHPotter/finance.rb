import { Controller } from "@hotwired/stimulus"
import { _applyMask, _removeMask } from "../utils/mask.js"

export default class extends Controller {
  connect() {
    document.addEventListener("turbo:click", () => this.element.classList.add("hidden"))
    document.addEventListener("turbo:frame-load", () => this.toggleBookmark())
  }

  toggleBookmark() {
    const mainTurboFrame = document.querySelector("turbo-frame#center_container")
    if (!mainTurboFrame) { return }

    const childTurboFrame = mainTurboFrame.querySelector("turbo-frame")
    if (!childTurboFrame) { return }

    const allowedContexts = ["budgets", "investments", "cash_transactions", "card_transactions", "card_transactions_search"]
    const isVisible = allowedContexts.includes(childTurboFrame.id)

    if (isVisible) {
      this.element.classList.remove("hidden")
      this.updateSum()
    } else {
      this.element.classList.add("hidden")
    }
  }

  updateSum() {
    const price = Array.from(document.querySelectorAll("#priceSum")).reduce((acc, span) => acc + parseInt(span.dataset.price), 0)
    const totalPriceSpan = document.querySelector("#totalPriceSum")
    totalPriceSpan.textContent = _applyMask(price.toString())
  }
}
