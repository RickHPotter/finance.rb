import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["kind", "creditField", "debitField", "bankAccount"]

  connect() {
    this.change()
  }

  change() {
    const credit = this.kindTarget.value === "credit"
    const debit = this.kindTarget.value === "debit"

    this.creditFieldTargets.forEach((field) => {
      field.classList.toggle("hidden", !credit)
      field.querySelectorAll("input, select").forEach((input) => { input.disabled = !credit })
    })

    this.debitFieldTargets.forEach((field) => { field.classList.toggle("hidden", !debit) })
    this.bankAccountTarget.disabled = !debit
  }
}
