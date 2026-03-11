import { Controller } from "@hotwired/stimulus"
import { _applyMask } from "../utils/mask.js"

export default class extends Controller {
  connect() {
    this.hide = this.hide.bind(this)
    this.refresh = this.refresh.bind(this)

    document.addEventListener("turbo:click", this.hide)
    document.addEventListener("turbo:frame-load", this.refresh)
    document.addEventListener("turbo:load", this.refresh)
    document.addEventListener("turbo:render", this.refresh)
    window.addEventListener("popstate", this.refresh)
    window.addEventListener("pageshow", this.refresh)

    this.refresh()
  }

  disconnect() {
    document.removeEventListener("turbo:click", this.hide)
    document.removeEventListener("turbo:frame-load", this.refresh)
    document.removeEventListener("turbo:load", this.refresh)
    document.removeEventListener("turbo:render", this.refresh)
    window.removeEventListener("popstate", this.refresh)
    window.removeEventListener("pageshow", this.refresh)
  }

  hide() {
    this.element.classList.add("hidden")
  }

  refresh() {
    requestAnimationFrame(() => this.toggleBookmark())
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
    const price = Array.from(document.querySelectorAll("#priceSum")).reduce((acc, span) => acc + parseInt(span.dataset.price || "0", 10), 0)
    const totalPriceSpan = document.querySelector("#totalPriceSum")
    if (!totalPriceSpan) { return }

    totalPriceSpan.textContent = _applyMask(price.toString())
  }
}
