import { Controller } from "@hotwired/stimulus"
import { _applyMask, _removeMask } from "../utils/mask.js"

export default class extends Controller {
  static targets = ["value", "remaining", "adjustment", "signToggle"]
  static values = { consumed: Number }

  connect() {
    this.updateRemaining()
    this.clampAdjustment()
  }

  updateRemaining() {
    if (!this.hasValueTarget || !this.hasRemainingTarget) return

    const value = this.currentValue()
    const remaining = value - this.consumedValue
    this.remainingTarget.value = _applyMask(remaining.toString())
  }

  toggleAdjustmentSign() {
    if (!this.hasAdjustmentTarget || !this.hasSignToggleTarget) return

    const sign = this.adjustmentTarget.dataset.sign === "+" ? "-" : "+"
    this.adjustmentTarget.dataset.sign = sign
    this.signToggleTarget.textContent = sign
    this.signToggleTarget.classList.toggle("bg-green-300", sign === "+")
    this.signToggleTarget.classList.toggle("bg-red-300", sign === "-")

    const adjustment = Math.abs(this.rawAdjustment())
    this.adjustmentTarget.value = _applyMask((sign === "-" ? adjustment * -1 : adjustment).toString())
    this.clampAdjustment()
  }

  clampAdjustment() {
    if (!this.hasAdjustmentTarget) return

    const currentValue = this.currentValue()
    let adjustment = this.rawAdjustment()

    if (adjustment > 0) {
      adjustment = Math.min(adjustment, Math.abs(Math.min(currentValue, 0)))
    }

    this.adjustmentTarget.value = _applyMask(adjustment.toString())
  }

  applyAdjustment() {
    if (!this.hasValueTarget || !this.hasAdjustmentTarget) return

    const nextValue = Math.min(this.currentValue() + this.rawAdjustment(), 0)
    this.valueTarget.value = _applyMask(nextValue.toString())
    this.valueTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.adjustmentTarget.value = _applyMask("0")
  }

  incrementAdjustment({ params }) {
    if (!this.hasAdjustmentTarget) return

    const increment = parseInt(params.adjustment, 10) || 0
    const adjustment = this.rawAdjustment() + increment
    this.adjustmentTarget.dataset.sign = adjustment < 0 ? "-" : "+"
    this.adjustmentTarget.value = _applyMask(adjustment.toString())
    this.updateSignToggle()
    this.clampAdjustment()
  }

  currentValue() {
    return parseInt(_removeMask(this.valueTarget.value || "0"), 10) || 0
  }

  rawAdjustment() {
    const value = parseInt(_removeMask(this.adjustmentTarget.value || "0"), 10) || 0
    return this.adjustmentTarget.dataset.sign === "-" ? Math.abs(value) * -1 : Math.abs(value)
  }

  updateSignToggle() {
    if (!this.hasSignToggleTarget) return

    const sign = this.adjustmentTarget.dataset.sign
    this.signToggleTarget.textContent = sign
    this.signToggleTarget.classList.toggle("bg-green-300", sign === "+")
    this.signToggleTarget.classList.toggle("bg-red-300", sign === "-")
  }
}
