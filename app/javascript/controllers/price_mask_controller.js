import { Controller } from "@hotwired/stimulus"
import { _applyMask, _removeMask } from "../utils/mask.js"

// Connects to data-controller="price-mask"
export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.applyMasks()
  }

  toggleSign({ target }) {
    const sign = target.textContent
    const priceTargets = this.element.querySelectorAll(target.dataset.target)

    switch (sign) {
      case "+":
        Array.from(priceTargets).forEach((priceTarget) => {
          priceTarget.dataset.sign = "-"
        })
        target.textContent = "-"
        target.classList.remove("bg-green-300")
        target.classList.add("bg-red-300")
        break
      case "-":
        Array.from(priceTargets).forEach((priceTarget) => {
          priceTarget.dataset.sign = "+"
        })
        target.textContent = "+"
        target.classList.remove("bg-red-300")
        target.classList.add("bg-green-300")
        break
      default:
        return
    }

    Array.from(priceTargets).forEach((priceTarget) => {
      const new_price = _removeMask(priceTarget.value) * - 1
      priceTarget.value = _applyMask(new_price.toString())
    })
  }

  applyMasks() {
    this.inputTargets.forEach(target => {
      target.value = _applyMask(target.value)
    })
  }

  applyMask({ target }) {
    const value = _removeMask(target.value)

    if (!target.dataset.sign) {
      target.value = _applyMask(value)
    }

    let absValue = Math.abs(value)
    if (target.dataset.sign == "-") {
      absValue = absValue * -1
    }

    target.value = _applyMask(absValue.toString())
  }

  removeMasks() {
    [...this.inputTargets].forEach((target) => {
      this.removeMask({ target })
    })

    this.element.querySelectorAll(".dynamic-price").forEach((target) => {
      this.removeMask({ target })
    })
  }

  removeMask({ target }) {
    target.value = _removeMask(target.value)
  }
}
