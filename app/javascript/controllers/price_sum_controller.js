import { Controller } from "@hotwired/stimulus"
import { _applyMask, _removeMask } from "../utils/mask.js"

export default class extends Controller {
  connect() {
    const price = Array.from(document.querySelectorAll("#priceSum")).reduce((acc, span) => acc + parseInt(span.dataset.price), 0)
    const totalPriceSpan = document.querySelector("#totalPriceSum")
    totalPriceSpan.textContent = _applyMask(price.toString())
  }
}
