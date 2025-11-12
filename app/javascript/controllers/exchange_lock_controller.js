import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["exchange", "price", "lockBtn", "unlockBtn"]

  connect() {
    this.toggleAllowedLocks()
  }

  lock(event) {
    const lockIcon = event.currentTarget
    const exchange = lockIcon.closest("[data-exchange-lock-target='exchange']")
    const exchangeIndex = this.exchangeTargets.indexOf(exchange)

    this.exchangeTargets.slice(0, exchangeIndex + 1).forEach(ex => {
      if (ex.dataset.locked !== "true") {
        ex.dataset.locked = "true"
        ex.classList.add("border-red-300")
        ex.classList.remove("border-green-300")
        ex.querySelector("[data-exchange-lock-target='lockBtn']").classList.add("hidden")
        ex.querySelector("[data-exchange-lock-target='unlockBtn']").classList.remove("hidden")
      }
    })

    this.toggleAllowedLocks()
    this.dispatch("locked")
  }

  unlock(event) {
    const lockIcon = event.currentTarget
    const exchange = lockIcon.closest("[data-exchange-lock-target='exchange']")
    const exchangeIndex = this.exchangeTargets.indexOf(exchange)

    this.exchangeTargets.slice(exchangeIndex).forEach(ex => {
      ex.dataset.locked = "false"
      ex.classList.add("border-green-300")
      ex.classList.remove("border-red-300")
      ex.querySelector("[data-exchange-lock-target='lockBtn']").classList.remove("hidden")
      ex.querySelector("[data-exchange-lock-target='unlockBtn']").classList.add("hidden")
    })

    this.toggleAllowedLocks()
    this.dispatch("unlocked")
  }

  toggleAllowedLocks() {
    let firstUnlockedIndex = -1
    this.exchangeTargets.forEach((exchange, index) => {
      if (exchange.dataset.locked !== "true" && firstUnlockedIndex === -1) {
        firstUnlockedIndex = index
      }
    })

    this.exchangeTargets.forEach((exchange, index) => {
      const lockBtn = exchange.querySelector("[data-exchange-lock-target='lockBtn']")

      if (firstUnlockedIndex !== -1 && index >= firstUnlockedIndex) {
        lockBtn.disabled = false
      } else {
        lockBtn.disabled = exchange.dataset.locked === "true"
      }
    })
  }
}
