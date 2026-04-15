import { Controller } from "@hotwired/stimulus"
import { _applyMask, _removeMask } from "../utils/mask.js"

// Connects to data-controller="price-mask"
export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.boundHandleKeydown = this.handleKeydown.bind(this)
    this.element.addEventListener("keydown", this.boundHandleKeydown)
    this.applyMasks()
  }

  disconnect() {
    this.element.removeEventListener("keydown", this.boundHandleKeydown)
  }

  toggleSign({ target }) {
    this.setSignForSelector(target.dataset.target, target.textContent === "+" ? "-" : "+")
  }

  applyMasks() {
    this.inputTargets.forEach(target => {
      if (this.isBlankPriceValue(target.value)) return

      target.value = _applyMask(target.value)
    })
  }

  applyMask({ target }) {
    const value = _removeMask(target.value)
    const min = target.dataset.min ? parseInt(target.dataset.min) : undefined
    const max = target.dataset.max ? parseInt(target.dataset.max) : undefined

    if (this.isBlankPriceValue(target.value)) {
      target.value = ""
      return
    }

    if (!target.dataset.sign && min == undefined && max == undefined) {
      target.value = _applyMask(value)
    }

    let absValue = Math.abs(value)
    if (target.dataset.sign == "-") {
      absValue = absValue * -1
    }

    if (min && absValue < min) {
      absValue = min
    }

    if (max && absValue > max) {
      absValue = max
    }

    target.value = _applyMask(absValue.toString())
  }

  handleKeydown(event) {
    if (!(event.target instanceof HTMLInputElement)) return
    if (!event.target.dataset.sign) return
    if (event.key !== "+" && event.key !== "-") return

    event.preventDefault()
    this.setSignForInput(event.target, event.key)
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

  setSignForInput(input, sign) {
    const toggleButton = this.signToggleButtons().find((button) => {
      const selector = button.dataset.target
      return selector && input.matches(selector)
    })

    if (toggleButton?.dataset.target) {
      this.setSignForSelector(toggleButton.dataset.target, sign)
      return
    }

    this.updatePriceTargets([ input ], sign)
  }

  setSignForSelector(selector, sign) {
    const priceTargets = Array.from(this.element.querySelectorAll(selector))
    this.updatePriceTargets(priceTargets, sign)
    this.signToggleButtons()
      .filter((button) => button.dataset.target === selector)
      .forEach((button) => this.updateToggleButton(button, sign))
  }

  updatePriceTargets(priceTargets, sign) {
    priceTargets.forEach((priceTarget) => {
      const rawValue = _removeMask(priceTarget.value || "")
      priceTarget.dataset.sign = sign

      if (this.isBlankPriceValue(rawValue)) return

      const absoluteValue = Math.abs(parseInt(rawValue, 10) || 0)
      const nextValue = sign === "-" ? absoluteValue * -1 : absoluteValue
      priceTarget.value = _applyMask(nextValue.toString())
    })
  }

  signToggleButtons() {
    return Array.from(this.element.querySelectorAll("[data-action*='price-mask#toggleSign']"))
  }

  updateToggleButton(button, sign) {
    button.textContent = sign
    button.classList.toggle("bg-green-300", sign === "+")
    button.classList.toggle("bg-red-300", sign === "-")
  }

  isBlankPriceValue(value) {
    const rawValue = _removeMask(value || "")
    return rawValue === "" || rawValue === "-"
  }
}
