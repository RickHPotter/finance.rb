import { Controller } from "@hotwired/stimulus"
import RailsDate from "models/railsDate"

// Connects to data-controller="reactive-form"
const is_empty = (value) => {
  return value === "" || value === null || value === undefined
}

const is_present = (value) => {
  return !is_empty(value)
}

const sleep = (fn, time = 0) => {
  return new Promise((resolve) => setTimeout(resolve, time))
    .then(fn)
}

export default class extends Controller {
  static targets = [
    "input", "dateInput", "priceInput",
    "closingDateDay", "daysUntilDueDate",

    "installmentWrapper", "monthYearInstallment", "priceInstallmentInput", "installmentsCountInput",
    "categoryTransactionWrapper",

    "addInstallment", "delInstallment",
    "addCategory", "delCategory",

    "updateButton"
  ]

  connect() {
    this.applyMasks()

    if (this.priceInstallmentInputTargets.length > 0) {
      this._updateInstallmentsPrices()
      this._updateChips()
    }
  }

  // Installments
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

    const rails_due_date = this._getDueDate()
    this._updateWrappers(rails_due_date)
  }

  updateInstallmentsPrices({ target }) {
    if (target.value < 1) { target.value = 1 }
    if (target.value > 72) { target.value = 72 }

    this._updateInstallmentsPrices()
  }

  // Categories
  insertChip({ target }) {
    const comboboxController = this.application.getControllerForElementAndIdentifier(target, "hw-combobox")
    if (!comboboxController) return console.error("Combobox controller not found")

    let all_options = comboboxController._allOptions
    let selected_option = comboboxController._selectedOptionElement
    if (!selected_option) return

    selected_option.classList.add("hidden")
    selected_option.dataset.filterableAs = ""
    let visible_options = all_options.filter((option) => { return !option.classList.contains("hidden") })

    this._insertChip(selected_option)

    comboboxController.clearOrToggleOnHandleClick()

    if (visible_options.length === 0) {
      comboboxController.close()
    } else {
      sleep(() => { comboboxController.actingCombobox.focus() })
    }
  }

  removeChip({ target }) {
    const nested_div = target.parentElement.parentElement.parentElement
    const chip_value = nested_div.querySelector(".category_transaction_category_id").value

    const combobox = this.element.querySelector('[data-action="hw-combobox:selection->reactive-form#insertChip"]')
    const comboboxController = this.application.getControllerForElementAndIdentifier(combobox, "hw-combobox")
    if (!comboboxController) return console.error("Combobox controller not found")

    let all_options = comboboxController._allOptions
    let removed_option = all_options.find((option) => { return option.dataset.value === chip_value })

    removed_option.classList.remove("hidden")
    removed_option.dataset.filterableAs = removed_option.dataset.autocompleteAs

    nested_div.remove()
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

  // Installments
  _getDueDate() {
    const current_closing_date_day = parseInt(this.closingDateDayTarget.value)
    const days_until_due_date = parseInt(this.daysUntilDueDateTarget.value)

    const rails_current_date = new RailsDate(this.dateInputTarget.value)
    const rails_closing_date = new RailsDate(rails_current_date.year, rails_current_date.month, current_closing_date_day)
    rails_closing_date.monthsForwards((rails_current_date.date() >= rails_closing_date.date()) ? 1 : 0)

    return new RailsDate(rails_closing_date).daysForwards(days_until_due_date)
  }

  _updateWrappers(starting_rails_date, starting_number = 0) {
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

  async _updateInstallmentsPrices() {
    const total_price = parseInt(this._removeMask(this.priceInputTarget.value))
    const installments_count = parseInt(this.installmentsCountInputTarget.value)

    let price_that_cannot_be_divided = total_price % installments_count
    const price_that_can_be_divided = total_price - price_that_cannot_be_divided
    const divisible_installment_price = price_that_can_be_divided / installments_count

    if (this.priceInstallmentInputTargets.length !== installments_count) { await this._updateInstallmentsFields() }

    this.priceInstallmentInputTargets.forEach((target) => {
      const value = (divisible_installment_price + Math.max(0, price_that_cannot_be_divided--)).toString()
      target.value = this._applyMask(value)
    })
  }

  async _updateInstallmentsFields() {
    const old_installments_count = this.priceInstallmentInputTargets.length
    const new_installments_count = parseInt(this.installmentsCountInputTarget.value)

    if (old_installments_count > new_installments_count) {
      const installments_to_be_deleted = this.delInstallmentTargets.slice(new_installments_count)
      installments_to_be_deleted.forEach((el) => el.click())

      return
    }

    const number_of_installments_to_add = new_installments_count - old_installments_count
    for (let i = 0; i < number_of_installments_to_add; i++) {
      await sleep(() => { this.addInstallmentTarget.click() })
    }

    const rails_due_date = this._getDueDate()
    this._updateWrappers(rails_due_date, old_installments_count)
  }

  // Categories
  _insertChip(selected_option) {
    const value = selected_option.dataset.value
    const text = selected_option.textContent

    this.addCategoryTarget.click()

    const wrappers = this.categoryTransactionWrapperTargets
    const new_wrapper = wrappers[wrappers.length - 1]

    new_wrapper.querySelector(".category_transaction_category_id").value = value
    new_wrapper.querySelector(".category_transaction_category_name").textContent = text
  }

  _updateChips() {
    // NOTE: sleeping here is due to the fact that the combobox controller is initialised AFTER reactive-form controller
    sleep(() => {
      const combobox = this.element.querySelector('[data-action="hw-combobox:selection->reactive-form#insertChip"]')
      const comboboxController = this.application.getControllerForElementAndIdentifier(combobox, "hw-combobox")
      if (!comboboxController) return console.error("Combobox controller not found")

      const chip_values = this.categoryTransactionWrapperTargets.map((target) => { return target.querySelector(".category_transaction_category_id").value })

      let all_options = comboboxController._allOptions
      let to_be_hidden = all_options.filter((option) => { return chip_values.includes(option.dataset.value) })

      to_be_hidden.forEach((option) => {
        option.classList.add("hidden")
        option.dataset.filterableAs = ""
      })
    })
  }
}
