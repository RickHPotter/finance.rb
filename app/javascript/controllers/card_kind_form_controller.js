import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["kind", "creditField", "debitField", "bankAccount"]

  connect() {
    this.change()
  }

  change() {
    const kind = this.kindTarget.querySelector("input:checked")?.value
    const credit = kind === "credit"
    const debit = kind === "debit"

    this.creditFieldTargets.forEach((field) => {
      field.classList.toggle("hidden", !credit)
      field.querySelectorAll("input, select").forEach((input) => { input.disabled = !credit })
    })

    this.debitFieldTargets.forEach((field) => { field.classList.toggle("hidden", !debit) })
    this.bankAccountTarget.querySelectorAll("input, button").forEach((input) => { input.disabled = !debit })
  }
}
