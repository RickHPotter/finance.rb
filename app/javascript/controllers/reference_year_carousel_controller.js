import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["yearBadge", "previousButton", "nextButton", "card"]
  static values = { years: Array }

  connect() {
    this.index = Math.max(this.yearsValue.length - 1, 0)
    this.render()
  }

  previous() {
    if (this.index <= 0) return

    this.index -= 1
    this.render()
  }

  next() {
    if (this.index >= this.yearsValue.length - 1) return

    this.index += 1
    this.render()
  }

  render() {
    const selectedYear = this.yearsValue[this.index]
    this.yearBadgeTarget.textContent = selectedYear || ""

    this.cardTargets.forEach((card) => {
      card.classList.toggle("hidden", Number(card.dataset.referenceYear) !== selectedYear)
    })

    this.previousButtonTarget.disabled = this.index <= 0
    this.nextButtonTarget.disabled = this.index >= this.yearsValue.length - 1
  }
}
