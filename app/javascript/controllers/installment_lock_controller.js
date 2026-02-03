import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["installment", "price", "lockBtn", "unlockBtn"]

  connect() {
    this.toggleAllowedLocks()
  }

  lock(event) {
    const lockIcon = event.currentTarget
    const installment = lockIcon.closest("[data-installment-lock-target='installment']")
    const installmentIndex = this.installmentTargets.indexOf(installment)

    this.installmentTargets.slice(0, installmentIndex + 1).forEach(inst => {
      if (inst.dataset.locked !== "true") {
        inst.dataset.locked = "true"
        inst.classList.add("border-red-300")
        inst.classList.remove("border-gray-300")
        inst.querySelector("[data-installment-lock-target='lockBtn']").classList.add("hidden")
        inst.querySelector("[data-installment-lock-target='unlockBtn']").classList.remove("hidden")
      }
    })

    this.toggleAllowedLocks()
    this.dispatch("locked")
  }

  unlock(event) {
    const lockIcon = event.currentTarget
    const installment = lockIcon.closest("[data-installment-lock-target='installment']")
    const installmentIndex = this.installmentTargets.indexOf(installment)

    this.installmentTargets.slice(installmentIndex).forEach(inst => {
      inst.dataset.locked = "false"
      inst.classList.add("border-gray-300")
      inst.classList.remove("border-red-300")
      inst.querySelector("[data-installment-lock-target='lockBtn']").classList.remove("hidden")
      inst.querySelector("[data-installment-lock-target='unlockBtn']").classList.add("hidden")
    })

    this.toggleAllowedLocks()
    this.dispatch("unlocked")
  }

  toggleAllowedLocks() {
    let firstUnlockedIndex = -1
    this.installmentTargets.forEach((installment, index) => {
      if (installment.dataset.locked !== "true" && firstUnlockedIndex === -1) {
        firstUnlockedIndex = index
      }
    })

    this.installmentTargets.forEach((installment, index) => {
      const lockBtn = installment.querySelector("[data-installment-lock-target='lockBtn']")

      if (firstUnlockedIndex !== -1 && index >= firstUnlockedIndex) {
        lockBtn.disabled = false
      } else {
        lockBtn.disabled = installment.dataset.locked === "true"
      }
    })
  }
}
