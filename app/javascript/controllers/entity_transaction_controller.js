import { Controller } from "@hotwired/stimulus"
import { initModals } from "flowbite"
import RailsDate from "../models/railsDate"
import { _removeMask, _applyMask } from "../utils/mask.js"

// FIXME: this is almost a total copy-paste from reactive-form-controller, i will deal with this after it is working
export default class extends Controller {
  static targets = ["priceInput", "priceToBeReturnedInput", "priceExchangeInput", "exchangesCountInput", "exchangeWrapper", "monthYearExchange", "addExchange", "delExchange"]

  connect() {
    initModals()
    this.checkForExchangeCategory()
  }

  toggleExchanges({ target }) {
    const price = parseInt(_removeMask(target.value))
    const shouldBeDisabled = price === 0

    if (shouldBeDisabled !== this.exchangesCountInputTarget.disabled) {
      this.exchangesCountInputTarget.disabled = shouldBeDisabled

      if (shouldBeDisabled) {
        this.exchangesCountInputTarget.value = 0
        this.delExchangeTargets.forEach((element) => element.click())
        this.exchangesCountInputTarget.classList.add("opacity-50")
      } else {
        this.exchangesCountInputTarget.classList.remove("opacity-50")
      }
    }

    if (this.exchangesCountInputTarget.value > 0) this.checkForExchangeCategory()
  }

  fillPrice({ target }) {
    const divider = target.dataset.divider
    const cardTransactionPriceStr = document.getElementById("card_transaction_price")
    const cashTransactionPriceStr = document.getElementById("cash_transaction_price")
    const priceStr = ( cardTransactionPriceStr || cashTransactionPriceStr ).value
    const price = parseInt(this._removeMask(priceStr) / divider)

    this.element.querySelector("input[name*='[price]']").value = this._applyMask(price.toString())
    this._updateExchangesPrices()
  }

  updatePrice() {
    const totalPrice = parseInt(_removeMask(document.querySelector("#transaction_price").value))
    const priceToBeReturned = parseInt(_removeMask(this.priceToBeReturnedInputTarget.value))
    const price = parseInt(_removeMask(this.priceInputTarget.value))

    if (totalPrice < priceToBeReturned) { this.priceToBeReturnedInputTarget.value = this._applyMask(totalPrice.toString()) }
    if (totalPrice < price) { this.priceInputTarget.value = this._applyMask(totalPrice.toString()) }
    if (priceToBeReturned > price) { this.priceInputTarget.value = this._applyMask(priceToBeReturned.toString()) }
  }

  updateExchangesPrices({ target }) {
    if (target.value < 0) { target.value = 0 }
    if (target.value > 72) { target.value = 72 }

    this._updateExchangesPrices()

    if (target.value > 0) this.checkForExchangeCategory()
  }

  checkForExchangeCategory() {
    const reactiveFormTarget = document.querySelector("#transaction_form")
    const comboboxController = this.application.getControllerForElementAndIdentifier(reactiveFormTarget, "reactive-form")
    if (!comboboxController) return console.error("Combobox controller not found")

    if (this.exchangeWrapperTargets.length > 0) {
      comboboxController._insertExchangeCategory()
    } else {
      comboboxController._removeExchangeCategory()
    }
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

  async _updateExchangesPrices() {
    const total_price         = parseInt(this._removeMask(this.priceToBeReturnedInputTarget.value))
    const new_exchanges_count = parseInt(this.exchangesCountInputTarget.value)

    let price_that_cannot_be_divided  = total_price % new_exchanges_count
    const price_that_can_be_divided   = total_price - price_that_cannot_be_divided
    const divisible_exchange_price    = price_that_can_be_divided / new_exchanges_count

    await this._updateExchangesFields(new_exchanges_count)

    const visible_exchanges_inputs = this.priceExchangeInputTargets.filter((element) => element.checkVisibility())

    visible_exchanges_inputs.forEach((target) => {
      const value  = (divisible_exchange_price + Math.max(0, price_that_cannot_be_divided--)).toString()
      target.value = this._applyMask(value)
    })
  }

  async _updateExchangesFields(new_exchanges_count) {
    const all_exchanges           = this.priceExchangeInputTargets
    const all_exchanges_count     = all_exchanges.length
    const visible_exchanges       = all_exchanges.filter((element) => element.checkVisibility())
    const visible_exchanges_count = visible_exchanges.length

    const should_remove_exchanges     = new_exchanges_count < visible_exchanges_count
    const should_add_exchanges        = new_exchanges_count > visible_exchanges_count
    const can_update_hidden_exchanges = all_exchanges_count > visible_exchanges_count

    if (visible_exchanges_count === new_exchanges_count) { return }

    if (should_remove_exchanges) {
      const exchanges_delete_buttons_to_be_clicked = this.delExchangeTargets.slice(new_exchanges_count)

      exchanges_delete_buttons_to_be_clicked.forEach((element) => element.click())
    }

    if (!should_add_exchanges) { return }

    if (can_update_hidden_exchanges) {
      const sliced = this.exchangeWrapperTargets.slice(visible_exchanges_count, new_exchanges_count)

      sliced.forEach(element => {
        element.style.display = "block"
        element.querySelector("input[name*='_destroy']").value = "0"
      })
    }

    const number_of_new_exchanges_to_add = new_exchanges_count - all_exchanges_count
    for (let i = 0; i < number_of_new_exchanges_to_add; i++) {
      await this.addExchangeTarget.click()
    }

    const rails_due_date = this._getDueDate()
    this._updateWrappers(rails_due_date, visible_exchanges_count)
  }

  _updateWrappers(starting_rails_date, starting_number = 0) {
    if (starting_number === 0 && this.monthYearExchangeTarget.textContent.trim() === starting_rails_date.monthYear()) { return }

    starting_rails_date.monthsForwards(starting_number)

    const visible_exchanges_wrappers = this.exchangeWrapperTargets.filter((element) => element.checkVisibility())

    visible_exchanges_wrappers.slice(starting_number).forEach((target, index) => {
      target.querySelector(".exchange_month_year").textContent = starting_rails_date.monthYear()
      target.querySelector(".exchange_number").value = index + starting_number + 1

      starting_rails_date.monthsForwards(1)
    })
  }

  _getDueDate() {
    const cardTransactionDate = document.getElementById("card_transaction_date")
    const cashTransactionDate = document.getElementById("cash_transaction_date")
    const dateStr = ( cardTransactionDate || cashTransactionDate ).value

    return new RailsDate(dateStr)
  }
}
