import { Controller } from "@hotwired/stimulus"
import { initModals } from "flowbite"
import RailsDate from "../models/railsDate"
import { sleep } from "../utils/utils.js"
import { _removeMask, _applyMask } from "../utils/mask.js"

// TODO: this is almost a total copy-paste from reactive-form-controller, i will deal with this after it is working
export default class extends Controller {
  static targets = [
    "priceInput", "priceToBeReturnedInput", "priceExchangeInput", "exchangesCountInput", "exchangesCountEqualsButton",
    "boundType", "exchangeWrapper", "monthYearExchange", "addExchange", "delExchange"
  ]

  connect() {
    initModals()
  }

  async toggleExchanges({ target }) {
    const price = parseInt(_removeMask(target.value))
    const shouldBeDisabled = price === 0

    if (shouldBeDisabled !== this.exchangesCountInputTarget.disabled) {
      this.exchangesCountInputTarget.disabled = shouldBeDisabled
      this.exchangesCountEqualsButtonTarget.disabled = shouldBeDisabled

      this.exchangesCountInputTarget.value = document.querySelector("[data-reactive-form-target='installmentsCountInput']").value
      await this._updateExchangesPrices()

      if (shouldBeDisabled) {
        this.exchangesCountInputTarget.value = 0
        this.delExchangeTargets.forEach((element) => element.click())
        this.exchangesCountInputTarget.classList.add("opacity-50")
      } else {
        this.exchangesCountInputTarget.classList.remove("opacity-50")
      }
    }

    this.checkForExchangeCategory()
  }

  async fillPrice({ target }) {
    const divider = target.dataset.divider
    const inputTarget = target.dataset.target
    const priceStr = document.getElementById("transaction_price").value
    const price = parseInt(this._removeMask(priceStr) / divider) * - 1

    switch (inputTarget) {
      case "priceInput":
        if (price < parseInt(this._removeMask(this.priceToBeReturnedInputTarget.value))) {
          this.priceToBeReturnedInputTarget.value = this._applyMask(price.toString())
        }
        this.priceInputTarget.value = this._applyMask(price.toString())
        break
      case "priceToBeReturnedInput":
        if (price > parseInt(this._removeMask(this.priceInputTarget.value))) {
          this.priceInputTarget.value = this._applyMask(price.toString())
        }
        this.priceToBeReturnedInputTarget.value = this._applyMask(price.toString())
        break
    }

    await this.toggleExchanges({ target: this.priceToBeReturnedInputTarget })
    await this._updateExchangesPrices()
  }

  updatePrice() {
    const totalPrice = parseInt(_removeMask(document.querySelector("#transaction_price").value)) * - 1
    const priceToBeReturned = parseInt(_removeMask(this.priceToBeReturnedInputTarget.value))
    const price = parseInt(_removeMask(this.priceInputTarget.value))

    if (totalPrice < priceToBeReturned) { this.priceToBeReturnedInputTarget.value = this._applyMask(totalPrice.toString()) }
    if (totalPrice < price) { this.priceInputTarget.value = this._applyMask(totalPrice.toString()) }
    if (priceToBeReturned > price) { this.priceInputTarget.value = this._applyMask(priceToBeReturned.toString()) }
    this._updateExchangesPrices()
  }

  async updateExchangesPrices({ target }) {
    if (target.value < 0) { target.value = 0 }
    if (target.value > 72) { target.value = 72 }

    await this._updateExchangesPrices()
    this.fillInBoundType({ target: this.boundTypeTargets.find((element) => element.checked) })

    this.checkForExchangeCategory()
  }

  checkForExchangeCategory() {
    const reactiveFormTarget = document.querySelector("#transaction_form")
    const comboboxController = this.application.getControllerForElementAndIdentifier(reactiveFormTarget, "reactive-form")
    if (!comboboxController) return console.error("Combobox controller not found")
    const exchangesWrappers = document.querySelectorAll(".nested-exchange-wrapper")
    const ongoingExchanges = Array.from(exchangesWrappers).filter((element) => element.querySelector(".exchange_destroy").value == "false")

    if (ongoingExchanges.length > 0) {
      comboboxController._insertExchangeCategory()
    } else {
      comboboxController._removeExchangeCategory()
    }
  }

  fillInBoundType({ target }) {
    if (!target) return

    this.element.querySelectorAll(".bound_type").forEach((element) => element.value = target.value)
  }

  copyTransactionInstallmentsCount() {
    this.exchangesCountInputTarget.value = document.querySelector("[data-reactive-form-target='installmentsCountInput']").value
    this.exchangesCountInputTarget.dispatchEvent(new Event("input"))
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
    const totalCents     = parseInt(this._removeMask(this.priceToBeReturnedInputTarget.value))
    const exchangesCount = parseInt(this.exchangesCountInputTarget.value)

    const baseCents = Math.floor(totalCents / exchangesCount)
    const remainder = totalCents - baseCents * exchangesCount

    await this._updateExchangesFields(exchangesCount)

    const visibleExchangesInputs = this.priceExchangeInputTargets.filter((element) => element.checkVisibility())

    visibleExchangesInputs.forEach((input, index) => {
      const valueCents = baseCents + (index < remainder ? 1 : 0)
      const value = (valueCents / 100).toFixed(2)
      input.value = this._applyMask(value)
    })
  }

  async _updateExchangesFields(newExchangesCount) {
    const allExchanges          = this.priceExchangeInputTargets
    const allExchangesCount     = allExchanges.length
    const visibleExchanges      = allExchanges.filter((element) => element.checkVisibility())
    const visibleExchangesCount = visibleExchanges.length

    const shouldRemoveExchanges    = newExchangesCount < visibleExchangesCount
    const shouldAddExchanges       = newExchangesCount > visibleExchangesCount
    const canUpdateHiddenExchanges = allExchangesCount > visibleExchangesCount

    if (visibleExchangesCount === newExchangesCount) { return }

    if (shouldRemoveExchanges) {
      const exchangesDeleteButtonsToBeClicked = this.delExchangeTargets.slice(newExchangesCount)

      exchangesDeleteButtonsToBeClicked.forEach((element) => element.click())
    }

    if (!shouldAddExchanges) { return }

    if (canUpdateHiddenExchanges) {
      const sliced = this.exchangeWrapperTargets.slice(visibleExchangesCount, newExchangesCount)

      sliced.forEach(element => {
        element.style.display = "block"
        element.querySelector("input[name*='_destroy']").value = "false"
      })
    }

    const numberOfNewExchangesToAdd = newExchangesCount - allExchangesCount
    for (let i = 0; i < numberOfNewExchangesToAdd; i++) {
      await new Promise((resolve) => setTimeout(resolve, 50))
      this.addExchangeTarget.click()
    }

    const railsDueDate = this._getDueDate()
    this._updateWrappers(railsDueDate, visibleExchangesCount)
  }

  _updateWrappers(startingRailsDate, startingNumber = 0) {
    if (startingNumber === 0 && this.monthYearExchangeTarget.textContent.trim() === startingRailsDate.monthYear()) { return }

    startingRailsDate.monthsForwards(startingNumber)

    const visibleExchangesWrappers = this.exchangeWrapperTargets.filter((element) => element.checkVisibility())

    visibleExchangesWrappers.slice(startingNumber).forEach((target, index) => {
      target.querySelector(".exchange_month_year").textContent = startingRailsDate.monthYear()
      target.querySelector(".exchange_number").value = index + startingNumber + 1

      startingRailsDate.monthsForwards(1)
    })
  }

  _getDueDate() {
    const year = parseInt(document.querySelector(".installment_year").value)
    const month = parseInt(document.querySelector(".installment_month").value)

    return new RailsDate(year, month, 1)
  }
}
