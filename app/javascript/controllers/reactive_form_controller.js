import { Controller } from "@hotwired/stimulus"
import RailsDate from "../models/railsDate"

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

    "installmentWrapper", "addInstallment", "delInstallment",
    "monthYearInstallment", "priceInstallmentInput", "installmentsCountInput",

    "categoryWrapper", "addCategory", "delCategory",
    "categoryColours",

    "entityWrapper",
    "addEntity", "delEntity",

    "updateButton"
  ]

  connect() {
    this.debounceTimeout = null

    this.applyMasks()

    const inputs_with_placeholder = this.inputTargets.filter(e => e.dataset.placeholder)
    inputs_with_placeholder.forEach(e => this.blink_placeholder(e))

    if (this.element.querySelector("#categories_nested")) {
      this._updateCategories()
    }

    if (this.element.querySelector("#entities_nested")) {
      this._updateEntities()
    }

    if (this.hasPriceInstallmentInputTargets) {
      this._updateInstallmentsPrices()
    }

    if (this.hasCategoryColoursTarget) {
      this.categoryColours = JSON.parse(this.categoryColoursTarget.value)
    }
  }

  blink_placeholder(input) {
    const symbol = "█"
    const text = input.dataset.placeholder

    const toggleBlink = () => {
      const lastChar = input.placeholder.at(-1)
      const cursor = lastChar === symbol ? " " : symbol
      input.placeholder = `${text}${cursor}`
    }

    const blinkInterval = setInterval(toggleBlink, 500)

    input.dataset.blinkInterval = blinkInterval;
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
  insertCategory({ target }) {
    const comboboxController = this.application.getControllerForElementAndIdentifier(target, "hw-combobox")
    if (!comboboxController) return console.error("Combobox controller not found")

    let all_options = comboboxController._allOptions
    let selected_option = comboboxController._selectedOptionElement
    if (!selected_option) return

    this._insertCategory(selected_option)

    comboboxController.clearOrToggleOnHandleClick()

    let visible_options = all_options.filter((option) => { return !option.classList.contains("hidden") })

    if (visible_options.length === 0) {
      comboboxController.close()
    } else {
      sleep(() => { comboboxController.actingCombobox.focus() })
    }
  }

  removeCategory({ target }) {
    const nested_div = target.parentElement.parentElement.parentElement
    const chip_value = nested_div.querySelector(".categories_category_id").value

    const combobox = this.element.querySelector("#hw_category_id .hw-combobox")
    const comboboxController = this.application.getControllerForElementAndIdentifier(combobox, "hw-combobox")
    if (!comboboxController) return console.error("Combobox controller not found")

    let all_options = comboboxController._allOptions
    let removed_option = all_options.find((option) => { return option.dataset.value === chip_value })

    if (removed_option) {
      removed_option.classList.remove("hidden")
      removed_option.dataset.filterableAs = removed_option.dataset.autocompleteAs
    }

    nested_div.style.display = "none"
    nested_div.querySelector("input[name*='_destroy']").value = "true"
  }

  // Entities
  insertEntity({ target }) {
    const comboboxController = this.application.getControllerForElementAndIdentifier(target, "hw-combobox")
    if (!comboboxController) return console.error("Combobox controller not found")

    let all_options = comboboxController._allOptions
    let selected_option = comboboxController._selectedOptionElement
    if (!selected_option) return

    this._insertEntity(selected_option)

    comboboxController.clearOrToggleOnHandleClick()

    let visible_options = all_options.filter((option) => { return !option.classList.contains("hidden") })

    if (visible_options.length === 0) {
      comboboxController.close()
    } else {
      sleep(() => { comboboxController.actingCombobox.focus() })
    }
  }

  removeEntity({ target }) {
    const nested_div = target.parentElement.parentElement.parentElement
    const chip_value = nested_div.querySelector(".entities_entity_id").value

    const combobox = this.element.querySelector("#hw_entity_id .hw-combobox")
    const comboboxController = this.application.getControllerForElementAndIdentifier(combobox, "hw-combobox")
    if (!comboboxController) return console.error("Combobox controller not found")

    let all_options = comboboxController._allOptions
    let removed_option = all_options.find((option) => { return option.dataset.value === chip_value })

    if (removed_option) {
      removed_option.classList.remove("hidden")
      removed_option.dataset.filterableAs = removed_option.dataset.autocompleteAs
    }

    nested_div.style.display = "none"
    nested_div.querySelector("input[name*='_destroy']").value = "true"
  }

  // search
  submit() {
    clearTimeout(this.debounceTimeout)

    this.debounceTimeout = setTimeout(() => {
      this.element.requestSubmit()
      sleep(() => { this.applyMasks() })
    }, 800)
  }

  // ░▒▓███████▓▒░░▒▓███████▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓██████▓▒░▒▓████████▓▒░▒▓████████▓▒░
  // ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░ ░▒▓█▓▒░   ░▒▓█▓▒
  // ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░ ░▒▓█▓▒░   ░▒▓█▓▒
  // ░▒▓███████▓▒░░▒▓███████▓▒░░▒▓█▓▒░░▒▓█▓▒▒▓█▓▒░░▒▓████████▓▒░ ░▒▓█▓▒░   ░▒▓██████▓▒░
  // ░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░ ░▒▓█▓▓█▓▒░ ░▒▓█▓▒░░▒▓█▓▒░ ░▒▓█▓▒░   ░▒▓█▓▒░
  // ░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░ ░▒▓█▓▓█▓▒░ ░▒▓█▓▒░░▒▓█▓▒░ ░▒▓█▓▒░   ░▒▓█▓▒░
  // ░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░  ░▒▓██▓▒░  ░▒▓█▓▒░░▒▓█▓▒░ ░▒▓█▓▒░   ░▒▓████████▓▒░

  _applyMask(value) {
    const isNegative = value.startsWith("-")

    value = value.replace(/[^\d]/g, "")
    value = (value / 100).toFixed(2).toString()
    value = value.replace(/\B(?=(\d{3})+(?!\d))/g, ".")

    return (isNegative ? "-R$ " : "R$ ") + value
  }

  _removeMask(value) {
    return value.replace(/[^\d-]/g, "")
  }

  // Installments
  _getDueDate() {
    if (!this.hasClosingDateDayTarget) { return new RailsDate(this.dateInputTarget.value) }
    return new RailsDate(this.element.querySelector(".installment_date").value)

    const current_closing_date_day = parseInt(this.closingDateDayTarget.value)
    const days_until_due_date = parseInt(this.daysUntilDueDateTarget.value)

    const rails_current_date = new RailsDate(this.dateInputTarget.value)
    const rails_closing_date = new RailsDate(rails_current_date.year, rails_current_date.month, current_closing_date_day)
    rails_closing_date.monthsForwards((rails_current_date.date() >= rails_closing_date.date()) ? 1 : 0)

    return new RailsDate(rails_closing_date).daysForwards(days_until_due_date)
  }

  _updateWrappers(starting_rails_date, starting_number = 0) {
    if (starting_number === 0 && this.monthYearInstallmentTarget.textContent.trim() === starting_rails_date.monthYear()) { return }

    const visible_installments_wrappers = this.installmentWrapperTargets.filter((element) => element.checkVisibility())

    visible_installments_wrappers.forEach((target, index) => {
      starting_rails_date.monthsForwards(1)

      if (target.querySelector(".installment_month").value) { return }

      const proposed_date = new RailsDate(starting_rails_date.year, starting_rails_date.month, new Date(this.dateInputTarget.value).getDate())

      target.querySelector(".installment_month_year").textContent = starting_rails_date.monthYear()
      target.querySelector(".installment_number").value = index + 1
      target.querySelector(".installment_date").value = proposed_date.date().toISOString().slice(0, 16)
      target.querySelector(".installment_month").value = starting_rails_date.month
      target.querySelector(".installment_year").value = starting_rails_date.year
    })
  }

  async _updateInstallmentsPrices() {
    const total_price            = parseInt(this._removeMask(this.priceInputTarget.value))
    const new_installments_count = parseInt(this.installmentsCountInputTarget.value)

    let price_that_cannot_be_divided  = total_price % new_installments_count
    const price_that_can_be_divided   = total_price - price_that_cannot_be_divided
    const divisible_installment_price = price_that_can_be_divided / new_installments_count

    await this._updateInstallmentsFields(new_installments_count)

    const visible_installments_inputs = this.priceInstallmentInputTargets.filter((element) => element.checkVisibility())

    visible_installments_inputs.forEach((target) => {
      const value  = (divisible_installment_price + Math.max(0, price_that_cannot_be_divided--)).toString()
      target.value = this._applyMask(value)
    })
  }

  async _updateInstallmentsFields(new_installments_count) {
    const all_installments           = this.priceInstallmentInputTargets
    const all_installments_count     = all_installments.length
    const visible_installments       = all_installments.filter((element) => element.checkVisibility())
    const visible_installments_count = visible_installments.length

    const should_remove_installments     = new_installments_count < visible_installments_count
    const should_add_installments        = new_installments_count > visible_installments_count
    const can_update_hidden_installments = all_installments_count > visible_installments_count

    if (visible_installments_count === new_installments_count) { return }

    if (should_remove_installments) {
      const installments_delete_buttons_to_be_clicked = this.delInstallmentTargets.slice(new_installments_count)

      installments_delete_buttons_to_be_clicked.forEach((element) => element.click())
    }

    if (!should_add_installments) { return }

    if (can_update_hidden_installments) {
      const sliced = this.installmentWrapperTargets.slice(visible_installments_count, new_installments_count)

      sliced.forEach(element => {
        element.style.display = "block"
        element.querySelector("input[name*='_destroy']").value = "0"
      })
    }

    const number_of_new_installments_to_add = new_installments_count - all_installments_count
    for (let i = 0; i < number_of_new_installments_to_add; i++) {
      await this.addInstallmentTarget.click()
    }

    const rails_due_date = this._getDueDate()
    const installments_count = this.priceInstallmentInputTargets.filter((element) => element.checkVisibility()).length
    this._updateWrappers(rails_due_date, installments_count)
  }

  // Categories
  _insertCategory(selected_option) {
    selected_option.classList.add("hidden")
    selected_option.dataset.filterableAs = ""

    const value = selected_option.dataset.value
    const text = selected_option.textContent

    this.addCategoryTarget.click()

    const wrappers = this.categoryWrapperTargets
    const new_wrapper = wrappers[wrappers.length - 1]

    new_wrapper.querySelector(".category_container").classList.add(this.categoryColours[value])
    new_wrapper.querySelector(".categories_category_id").value = value
    new_wrapper.querySelector(".categories_category_name").textContent = text
  }

  _updateCategories() {
    // NOTE: sleeping here is due to the fact that the combobox controller is initialised AFTER reactive-form controller
    sleep(() => {
      const combobox = this.element.querySelector("#hw_category_id .hw-combobox")
      const comboboxController = this.application.getControllerForElementAndIdentifier(combobox, "hw-combobox")
      if (!comboboxController) return console.error("Combobox controller not found")

      const chip_values = this.categoryWrapperTargets.map((target) => { return target.querySelector(".categories_category_id").value })

      let all_options = comboboxController._allOptions
      let to_be_hidden = all_options.filter((option) => { return chip_values.includes(option.dataset.value) })

      to_be_hidden.forEach((option) => {
        option.classList.add("hidden")
        option.dataset.filterableAs = ""
      })
    })
  }

  // Entities

  _insertEntity(selected_option) {
    selected_option.classList.add("hidden")
    selected_option.dataset.filterableAs = ""

    const value = selected_option.dataset.value
    const text = selected_option.textContent

    this.addEntityTarget.click()

    const wrappers = this.entityWrapperTargets
    const new_wrapper = wrappers[wrappers.length - 1]

    new_wrapper.querySelector(".entities_entity_id").value = value
    new_wrapper.querySelector(".entities_entity_name").textContent = text
  }

  _updateEntities() {
    // NOTE: sleeping here is due to the fact that the combobox controller is initialised AFTER reactive-form controller
    sleep(() => {
      const combobox = this.element.querySelector("#hw_entity_id .hw-combobox")
      const comboboxController = this.application.getControllerForElementAndIdentifier(combobox, "hw-combobox")
      if (!comboboxController) return console.error("Combobox controller not found")

      const chip_values = this.entityWrapperTargets.map((target) => { return target.querySelector(".entities_entity_id").value })

      let all_options = comboboxController._allOptions
      let to_be_hidden = all_options.filter((option) => { return chip_values.includes(option.dataset.value) })

      to_be_hidden.forEach((option) => {
        option.classList.add("hidden")
        option.dataset.filterableAs = ""
      })
    })
  }
}
