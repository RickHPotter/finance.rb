import { Controller } from "@hotwired/stimulus"
import { _applyMask, _removeMask } from "../utils/mask.js"

// Connects to data-controller="price-mask"
export default class extends Controller {
  static targets = ["priceInput"]

  connect() {
    this.applyMasks()
  }

  applyMasks() {
    this.priceInputTargets.forEach(target => {
      target.value = _applyMask(target.value)
    })
  }

  applyMask({ target }) {
    target.value = _applyMask(target.value)
  }

  removeMasks() {
    [...this.priceInputTargets].forEach((target) => {
      this.removeMask({ target })
    })
  }

  removeMask({ target }) {
    target.value = _removeMask(target.value)
  }
}
