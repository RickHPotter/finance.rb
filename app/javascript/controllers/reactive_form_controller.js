import { Controller } from "@hotwired/stimulus"
import RailsDate from "models/railsDate"

// Connects to data-controller="reactive-form"
const is_empty = (value) => {
  return value === "" || value === null || value === undefined
}

const is_present = (value) => {
  return !is_empty(value)
}

export default class extends Controller {
  static targets = [
    "input", "dateInput", "priceInput",
    "closingDateDay", "daysUntilDueDate",
    "installmentWrapper", "monthYearInstallment", "priceInstallmentInput", "installmentsCountInput",
    "addInstallment", "delInstallment", "updateButton"
  ]

  connect() {
    this.applyMasks()
  }

  requestSubmit({ target }) {
    const has_value = is_present(target.value) || (target.dataset.value && is_present(target.querySelector(target.dataset.value).value))

    if (has_value) { target.form.requestSubmit(this.updateButtonTarget) }
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

  updateInstallmentsDates() {
    if (this.dateInputTarget.value === "") { this.dateInputTarget.value = RailsDate.today() }

    const rails_due_date = this._get_due_date()
    this._update_wrappers(rails_due_date)
  }

  updateInstallmentsPrices({ target }) {
    if (target.value < 1) { target.value = 1 }
    if (target.value > 72) { target.value = 72 }

    this._update_installment_prices()
  }

  // ░▒▓███████▓▒░░▒▓███████▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓██████▓▒░▒▓████████▓▒░▒▓████████▓▒░
  // ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░ ░▒▓█▓▒░   ░▒▓█▓▒
  // ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░ ░▒▓█▓▒░   ░▒▓█▓▒
  // ░▒▓███████▓▒░░▒▓███████▓▒░░▒▓█▓▒░░▒▓█▓▒▒▓█▓▒░░▒▓████████▓▒░ ░▒▓█▓▒░   ░▒▓██████▓▒░
  // ░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░ ░▒▓█▓▓█▓▒░ ░▒▓█▓▒░░▒▓█▓▒░ ░▒▓█▓▒░   ░▒▓█▓▒░
  // ░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░ ░▒▓█▓▓█▓▒░ ░▒▓█▓▒░░▒▓█▓▒░ ░▒▓█▓▒░   ░▒▓█▓▒░
  // ░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░  ░▒▓██▓▒░  ░▒▓█▓▒░░▒▓█▓▒░ ░▒▓█▓▒░   ░▒▓████████▓▒░

  _applyMask(value) {
    value = value.replace(/\D/g, '')
    value = (value / 100).toFixed(2).toString()
    value = value.replace(/\B(?=(\d{3})+(?!\d))/g, ".")

    return "R$ " + value
  }

  _removeMask(value) {
    return value.replace(/[^\d]/g, "")
  }

  _get_due_date() {
    const current_closing_date_day = parseInt(this.closingDateDayTarget.value)
    const days_until_due_date = parseInt(this.daysUntilDueDateTarget.value)

    const rails_current_date = new RailsDate(this.dateInputTarget.value)
    const rails_closing_date = new RailsDate(rails_current_date.year, rails_current_date.month, current_closing_date_day)
    rails_closing_date.monthsForwards((rails_current_date.date() >= rails_closing_date.date()) ? 1 : 0)

    return new RailsDate(rails_closing_date).daysForwards(days_until_due_date)
  }

  _update_wrappers(starting_rails_date, starting_number = 0) {
    if (starting_number === 0 && this.monthYearInstallmentTarget.textContent.trim() === starting_rails_date.monthYear()) { return }

    starting_rails_date.monthsForwards(starting_number)

    this.installmentWrapperTargets.slice(starting_number).forEach((target, index) => {
      target.querySelector(".installment_month_year").textContent = starting_rails_date.monthYear()
      target.querySelector(".installment_number").value = index + starting_number + 1
      target.querySelector(".installment_month").value = starting_rails_date.month
      target.querySelector(".installment_year").value = starting_rails_date.year

      starting_rails_date.monthsForwards(1)
    })
  }

  _update_installment_prices() {
    const total_price = parseInt(this._removeMask(this.priceInputTarget.value))
    const installments_count = parseInt(this.installmentsCountInputTarget.value)

    let price_that_cannot_be_divided = total_price % installments_count
    const price_that_can_be_divided = total_price - price_that_cannot_be_divided
    const divisible_installment_price = price_that_can_be_divided / installments_count

    if (this.priceInstallmentInputTargets.length !== installments_count) { this._update_installments_fields() }

    this.priceInstallmentInputTargets.forEach((target) => {
      const value = (divisible_installment_price + Math.max(0, price_that_cannot_be_divided--)).toString()
      target.value = this._applyMask(value)
    })
  }

  _update_installments_fields() {
    const old_installments_count = this.priceInstallmentInputTargets.length
    const new_installments_count = parseInt(this.installmentsCountInputTarget.value)

    if (old_installments_count > new_installments_count) {
      const installments_to_be_deleted = this.delInstallmentTargets.slice(new_installments_count)
      installments_to_be_deleted.forEach((el) => el.click())

      return
    }

    const number_of_installments_to_add = new_installments_count - old_installments_count
    for (let i = 0; i < number_of_installments_to_add; i++) {
      this.addInstallmentTarget.click()
    }

    const rails_due_date = this._get_due_date()
    this._update_wrappers(rails_due_date, old_installments_count)
  }
}
