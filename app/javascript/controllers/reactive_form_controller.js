import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="reactive-form"
export default class extends Controller {
  static targets = ["input", "priceInput", "priceInstallmentInput", "installmentsCountInput", "updateButton"]

  connect() {
    this.applyMasks()
  }

  requestSubmit({ target }) {
    const has_value = target.value !== "" || target.dataset.value && target.querySelector(target.dataset.value).value !== ""

    if (has_value) target.form.requestSubmit(this.updateButtonTarget)
  }

  applyMasks() {
    [...this.priceInputTargets, ...this.priceInstallmentInputTargets].forEach((target) => {
      this.applyMask({ target })
    })
  }

  applyMask({ target }) {
    target.value = this._applyMask(target.value)
  }

  removeMasks() {
    [...this.priceInputTargets, ...this.priceInstallmentInputTargets].forEach((target) => {
      this.removeMask({ target })
    })
  }

  removeMask({ target }) {
    target.value = this._removeMask(target.value)
  }

  updateInstallmentsPrices() {
    const total_price = parseInt(this._removeMask(this.priceInputTarget.value))
    const installments_count = parseInt(this.installmentsCountInputTarget.value)

    let total_remaining = total_price % installments_count
    const remaining = Array(total_remaining).fill(1)
    const total_divisible = total_price - total_remaining
    const installment_price = total_divisible / installments_count

    this.priceInstallmentInputTargets.forEach((target) => {
      const value = (installment_price + (remaining.pop() || 0)).toString()
      const maskedValue = this._applyMask(value)
      target.value = maskedValue
    })
  }

  updateInstallmentsFields() {
    // FIXME: add a function for when installments_count is changed
  }

  // PRIVATE

  _applyMask(value) {
    value = value.replace(/\D/g, '')
    value = (value / 100).toFixed(2).toString()
    value = value.replace(/\B(?=(\d{3})+(?!\d))/g, ".")

    return "R$ " + value
  }

  _removeMask(value) {
    return value.replace(/[^\d]/g, "")
  }
}
