import { Controller } from "@hotwired/stimulus"
import RefMonthYear from "models/refMonthYear"

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
    "dueDate", "daysUntilDueDate",
    "priceInstallmentInput", "installmentsCountInput",
    "updateButton"
  ]

  connect() {
    this.applyMasks()
  }

  requestSubmit({ target }) {
    const has_value = is_present(target.value) || (target.dataset.value && is_present(target.querySelector(target.dataset.value).value))

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

  // FIXME: REFACTOR, FFS
  updateInstallmentsDates() {
    const days_until_due_date = parseInt(this.daysUntilDueDateTarget.value)
    const current_date = new Date(this.dateInputTarget.value + "T00:00")
    const current_due_date = new Date(this.dueDateTarget.value + "T00:00")

    const closing_date_based_on_current_date = new Date(current_date.getFullYear(), current_date.getMonth(), current_due_date.getDate() - days_until_due_date)

    const date =
      closing_date_based_on_current_date > current_date
        ? closing_date_based_on_current_date
        : new Date(closing_date_based_on_current_date.getFullYear(), closing_date_based_on_current_date.getMonth() + 1)

    const starting_month = date.getMonth()
    const starting_year = date.getFullYear()

    this.priceInstallmentInputTargets.forEach((target, index) => {
      const ref_date = new Date(starting_year, starting_month + index)
      console.table({ month: ref_date.getMonth(), year: ref_date.getFullYear() })
      const month_year = new RefMonthYear(ref_date.getMonth(), ref_date.getFullYear()).monthYear()

      const nested_form_wrapper = target.parentElement.parentElement.parentElement
      nested_form_wrapper.querySelector(".installment_month_year").textContent = month_year
    })
  }

  // FIXME: REFACTOR, FFS
  updateInstallmentsPrices({ target }) {
    if (target.value < 1) target.value = 1
    if (target.value > 72) target.value = 72

    const total_price = parseInt(this._removeMask(this.priceInputTarget.value))
    const installments_count = parseInt(this.installmentsCountInputTarget.value)
    const installments_targets = this.priceInstallmentInputTargets

    let total_remaining = total_price % installments_count
    const remaining = Array(total_remaining).fill(1)
    const total_divisible = total_price - total_remaining
    const installment_price = total_divisible / installments_count

    if (installments_targets.length !== installments_count) { this.updateInstallmentsFields() }

    this.priceInstallmentInputTargets.forEach((target) => {
      const value = (installment_price + (remaining.pop() || 0)).toString()
      const maskedValue = this._applyMask(value)
      target.value = maskedValue
    })
  }

  updateInstallmentsFields() {
    const document = this.priceInputTarget.ownerDocument.documentElement
    const add_installment_button = this.element.querySelector("#add_installment")

    const old_installments_count = this.priceInstallmentInputTargets.length
    const new_installments_count = parseInt(this.installmentsCountInputTarget.value)

    if (old_installments_count > new_installments_count) {
      const del_installment_buttons = [...document.querySelectorAll("#del_installment")].reverse()
      const installments_to_be_deleted = del_installment_buttons.slice(0, old_installments_count - new_installments_count)
      installments_to_be_deleted.forEach((el) => el.click())

      return
    }

    // FIXME: THIS IS HORRENDOUS
    const number_of_installments_to_add = new_installments_count - old_installments_count
    for (let i = 0; i < number_of_installments_to_add; i++) {
      add_installment_button.click()

      const new_installment = this.priceInstallmentInputTargets[this.priceInstallmentInputTargets.length - 1]
      const old_installment = this.priceInstallmentInputTargets[this.priceInstallmentInputTargets.length - 2]

      const old_installment_month = old_installment.parentElement.parentElement.parentElement.querySelector(".installment_month").value
      const old_installment_year = old_installment.parentElement.parentElement.parentElement.querySelector(".installment_year").value
      const new_installment_date = new Date(parseInt(old_installment_year), parseInt(old_installment_month))

      const month_year = new RefMonthYear(new_installment_date.getMonth(), new_installment_date.getFullYear()).monthYear()

      const nested_form_wrapper = new_installment.parentElement.parentElement.parentElement
      nested_form_wrapper.querySelector(".installment_number").value = this.priceInstallmentInputTargets.length
      nested_form_wrapper.querySelector(".installment_month").value = new_installment_date.getMonth() + 1
      nested_form_wrapper.querySelector(".installment_year").value = new_installment_date.getFullYear()
      nested_form_wrapper.querySelector(".installment_year").value = new_installment_date.getFullYear()
      nested_form_wrapper.querySelector(".installment_month_year").textContent = month_year
    }
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
