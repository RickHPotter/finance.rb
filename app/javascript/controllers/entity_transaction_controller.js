import { Controller } from "@hotwired/stimulus"
import { initModals } from "flowbite"
import RailsDate from "../models/railsDate"
import { sleep } from "../utils/utils.js"
import { _removeMask, _applyMask } from "../utils/mask.js"

// TODO: this is almost a total copy-paste from reactive-form-controller, i will deal with this after it is working
export default class extends Controller {
  static targets = [
    "button", "dateInput", "priceInput", "priceToBeReturnedInput", "priceExchangeInput", "exchangesCountInput", "exchangesCountEqualsButton",
    "boundType", "exchangeWrapper", "monthYearExchange", "addExchange", "delExchange", "loanReturnPercentageInput"
  ]

  async connect() {
    this.initModalOnce()
  }

  initModalOnce() {
    const modalEl = this.element.querySelector("[data-modal-id]")
    if (!modalEl) return

    const existing = window.FlowbiteInstances?.getInstance("Modal", modalEl.id)
    if (!existing) {
      initModals()
    }
  }

  async updateExchangeDate(target, count) {
    const exchangeWrapper = target.closest("[data-entity-transaction-target='exchangeWrapper']")
    if (exchangeWrapper.dataset.locked === "true") { return }

    const monthYearInput = exchangeWrapper.querySelector(".exchange_month_year")
    const monthInput = exchangeWrapper.querySelector(".exchange_month")
    const yearInput = exchangeWrapper.querySelector(".exchange_year")
    const dateInput = exchangeWrapper.querySelector(".exchange_date")
    const boundTypeInput = exchangeWrapper.querySelector(".bound_type")

    const date = new RailsDate(parseInt(yearInput.value), parseInt(monthInput.value), 1)
    date.monthsForwards(count)

    monthYearInput.textContent = date.monthYear()
    monthInput.value = date.month
    yearInput.value = date.year

    if (boundTypeInput.value === "card_bound") {
      const userCardId = document.querySelector("[name='card_transaction[user_card_id]']")?.value
      if (userCardId) {
        const response = await fetch(`/user_cards/${userCardId}/reference_date?year=${date.year}&month=${date.month}`)
        const data = await response.json()
        if (data.reference_date) {
          const referenceDate = new RailsDate(data.reference_date)
          dateInput.value = referenceDate.dateTime()
          this.refreshDatetimeInput(dateInput)
        }
      }
    }
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
        this.activeExchangeWrappers().forEach((wrapper) => this.deactivateExchangeWrapper(wrapper))
        this.exchangesCountInputTarget.classList.add("opacity-50")
      } else {
        this.exchangesCountInputTarget.classList.remove("opacity-50")
      }
    }

    this.checkForExchangeCategory()
  }

  async fillPrice({ target }) {
    const divider = Number(target.dataset.divider)
    const inputTarget = target.dataset.target
    const priceStr = document.getElementById("transaction_price").value
    const totalPrice = parseInt(this._removeMask(priceStr)) * - 1
    const price = Math.trunc(totalPrice / divider)

    switch (inputTarget) {
      case "priceInput":
        this.priceInputTarget.value = this._applyMask(price.toString())

        const priceToBeReturnedInput = parseInt(this._removeMask(this.priceToBeReturnedInputTarget.value))

        if (price > 0 === priceToBeReturnedInput > 0 && Math.abs(price) < Math.abs(priceToBeReturnedInput)) {
          this.priceToBeReturnedInputTarget.value = this._applyMask(price.toString())
        }

        break
      case "priceToBeReturnedInput":
        this.priceToBeReturnedInputTarget.value = this._applyMask(price.toString())

        const priceInput = parseInt(this._removeMask(this.priceInputTarget.value))

        if (priceInput === 0 || ( priceInput > 0 === price > 0 ) && Math.abs(price) > Math.abs(priceInput)) {
          this.priceInputTarget.value = this._applyMask(price.toString())
        }

        break
    }

    this._addBorderToPriceInputs(totalPrice)
    await this.toggleExchanges({ target: this.priceToBeReturnedInputTarget })
    await this._updateExchangesPrices()
  }

  async updatePrice() {
    const totalPrice = parseInt(_removeMask(document.querySelector("#transaction_price").value)) * - 1
    const priceToBeReturned = parseInt(_removeMask(this.priceToBeReturnedInputTarget.value))
    const price = parseInt(_removeMask(this.priceInputTarget.value))

    if (Math.abs(priceToBeReturned) > Math.abs(price) && !this.loanReturnPercentageIsActive()) {
      this.priceInputTarget.value = this._applyMask(priceToBeReturned.toString())
    }
    this._addBorderToPriceInputs(totalPrice)
    await this._updateExchangesPrices()
  }

  async applyLoanReturnPercentage() {
    if (!this.hasLoanReturnPercentageInputTarget) { return }

    const percentage = this.loanReturnPercentage()
    if (percentage === null) { return }

    const transactionCents = Math.abs(this.transactionTotalCents())
    if (!transactionCents) { return }

    const sign = this.entityPriceSign()
    const entityCents = Math.round(transactionCents * (percentage / 100)) * sign

    this.priceInputTarget.value = this._applyMask(entityCents.toString())
    this.priceToBeReturnedInputTarget.value = this._applyMask(entityCents.toString())

    await this.updatePrice()
    await this.toggleExchanges({ target: this.priceToBeReturnedInputTarget })
  }

  async resetLoanReturnPercentage() {
    if (!this.hasLoanReturnPercentageInputTarget) { return }

    this.loanReturnPercentageInputTarget.value = this.loanReturnPercentageInputTarget.dataset.originalValue || "100.0"
    await this.applyLoanReturnPercentage()
  }

  async matchLoanReturnPercentage() {
    if (!this.hasLoanReturnPercentageInputTarget) { return }

    const entityCents = Math.abs(parseInt(this._removeMask(this.priceToBeReturnedInputTarget.value)))
    const transactionCents = Math.abs(this.transactionTotalCents())
    if (!entityCents || !transactionCents) { return }

    const percentage = ((entityCents / transactionCents) * 100).toFixed(4)
    this.loanReturnPercentageInputTarget.value = this.trimTrailingZeroes(percentage)

    await this.applyLoanReturnPercentage()
  }

  loanReturnPercentage() {
    const value = this.loanReturnPercentageInputTarget.value.toString().replace(",", ".")
    if (!value.trim()) { return null }

    const percentage = Number(value)
    return Number.isFinite(percentage) ? percentage : null
  }

  loanReturnPercentageIsActive() {
    if (!this.hasLoanReturnPercentageInputTarget) { return false }

    return (this.loanReturnPercentage() || 100) !== 100
  }

  entityPriceSign() {
    const priceToBeReturnedCents = parseInt(this._removeMask(this.priceToBeReturnedInputTarget.value))
    if (priceToBeReturnedCents !== 0 && !Number.isNaN(priceToBeReturnedCents)) {
      return priceToBeReturnedCents < 0 ? -1 : 1
    }

    const priceCents = parseInt(this._removeMask(this.priceInputTarget.value))
    if (priceCents !== 0 && !Number.isNaN(priceCents)) {
      return priceCents < 0 ? -1 : 1
    }

    return this.transactionTotalCents() < 0 ? -1 : 1
  }

  transactionTotalCents() {
    return parseInt(this._removeMask(document.querySelector("#transaction_price").value)) * - 1
  }

  trimTrailingZeroes(value) {
    return value.toString().replace(/(\.\d*?)0+$/, "$1").replace(/\.$/, "")
  }

  _addBorderToPriceInputs(totalPrice) {
    if (Math.abs(totalPrice) < Math.abs(parseInt(this._removeMask(this.priceInputTarget.value)))) {
      this.priceInputTarget.classList.add("border-red-600")
    } else {
      this.priceInputTarget.classList.remove("border-red-600")
    }
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
    const cardBound = target.value === "card_bound"
    this.element.querySelectorAll(".exchange_date").forEach((element) => this.setExchangeDatetimeReadonly(element, cardBound))

    if (cardBound) {
      this.monthYearExchangeTarget.textContent = ""
      const railsDueDate = this._getDueDate()
      this._updateWrappers(railsDueDate, 0)

      const prevMonthTarget = this.element.querySelector("[data-entity-transaction-target='button']")
      this.updateExchangeDate(prevMonthTarget, 0)
    }
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

    await this._updateExchangesFields(exchangesCount)

    const activeExchanges   = this.activeExchangeWrappers()
    const lockedExchanges   = activeExchanges.filter((element) => element.dataset.locked === "true")
    const unlockedExchanges = activeExchanges.filter((element) => element.dataset.locked !== "true")

    let lockedPrice = 0
    lockedExchanges.forEach(exchange => {
      const priceInput = exchange.querySelector("[data-entity-transaction-target='priceExchangeInput']")
      lockedPrice += parseInt(this._removeMask(priceInput.value))
    })

    const remainingPrice = totalCents - lockedPrice
    const unlockedCount = unlockedExchanges.length

    if (unlockedCount > 0) {
      const baseCents = remainingPrice >= 0
        ? Math.floor(remainingPrice / unlockedCount)
        : Math.ceil(remainingPrice / unlockedCount)
      const remainder = remainingPrice - baseCents * unlockedCount

      unlockedExchanges.forEach((exchange, index) => {
        const priceInput = exchange.querySelector("[data-entity-transaction-target='priceExchangeInput']")
        const valueCents = index === 0 ? (baseCents + remainder) : baseCents
        priceInput.value = this._applyMask((valueCents / 100).toFixed(2))
      })
    }
  }

  async _updateExchangesFields(newExchangesCount) {
    const activeWrappers        = this.activeExchangeWrappers()
    const hiddenWrappers        = this.hiddenExchangeWrappers()
    const visibleExchangesCount = activeWrappers.length

    const shouldRemoveExchanges = newExchangesCount < visibleExchangesCount
    const shouldAddExchanges    = newExchangesCount > visibleExchangesCount

    if (visibleExchangesCount === newExchangesCount) { return }

    if (shouldRemoveExchanges) {
      activeWrappers.slice(newExchangesCount).forEach((wrapper) => this.deactivateExchangeWrapper(wrapper))
    }

    if (!shouldAddExchanges) { return }

    let railsDueDate
    const currentVisibleExchanges = this.activeExchangeWrappers()

    if (visibleExchangesCount > 0) {
        const lastExchange = currentVisibleExchanges[visibleExchangesCount - 1]
        const month = parseInt(lastExchange.querySelector(".exchange_month").value)
        const year = parseInt(lastExchange.querySelector(".exchange_year").value)
        railsDueDate = new RailsDate(year, month, 1)
    } else {
        railsDueDate = this._getDueDate()
    }

    const reusableHiddenWrappers = hiddenWrappers.slice(0, newExchangesCount - visibleExchangesCount)

    reusableHiddenWrappers.forEach((element) => this.activateExchangeWrapper(element))

    const numberOfNewExchangesToAdd = newExchangesCount - visibleExchangesCount - reusableHiddenWrappers.length
    for (let i = 0; i < numberOfNewExchangesToAdd; i++) {
      await new Promise((resolve) => setTimeout(resolve, 50))
      this.addExchangeTarget.click()
    }

    this._updateWrappers(railsDueDate, visibleExchangesCount)
  }

  activeExchangeWrappers() {
    return this.exchangeWrapperTargets.filter((element) => this.exchangeWrapperActive(element))
  }

  hiddenExchangeWrappers() {
    return this.exchangeWrapperTargets.filter((element) => !this.exchangeWrapperActive(element))
  }

  exchangeWrapperActive(element) {
    return this.exchangeDestroyInput(element)?.value !== "true"
  }

  exchangeDestroyInput(element) {
    return element.querySelector("input[name*='_destroy']")
  }

  activateExchangeWrapper(element) {
    const destroyInput = this.exchangeDestroyInput(element)
    if (destroyInput) destroyInput.value = "false"
    element.style.display = "block"
  }

  deactivateExchangeWrapper(element) {
    const destroyInput = this.exchangeDestroyInput(element)
    if (destroyInput) destroyInput.value = "true"
    element.style.display = "none"
  }

  _updateWrappers(startingRailsDate, startingNumber = 0) {
    const visibleExchangesWrappers = this.activeExchangeWrappers()
    if (visibleExchangesWrappers.length === 0) { return }

    let proposedDate
    if (startingNumber > 0) {
      const prevExchange = visibleExchangesWrappers[startingNumber - 1]
      const dateValue = prevExchange.querySelector(".exchange_date").value
      const monthValue = parseInt(prevExchange.querySelector(".exchange_month").value)
      const yearValue = parseInt(prevExchange.querySelector(".exchange_year").value)

      proposedDate = new RailsDate(dateValue)
      proposedDate.monthsForwards(1)
      startingRailsDate = new RailsDate(yearValue, monthValue, 1)
      startingRailsDate.monthsForwards(1)
    } else {
      proposedDate = new RailsDate(document.querySelector("#cash_transaction_date").value)
      proposedDate.setHour(0)
      proposedDate.setMinute(0)

      const boundType = this.boundTypeTargets.find((element) => element.checked)?.value
      if (boundType !== "card_bound") {
        proposedDate.daysForwards(1)
      }
    }

    visibleExchangesWrappers.slice(startingNumber).forEach((target, index) => {
      if (index > 0) {
        startingRailsDate.monthsForwards(1)
        proposedDate.monthsForwards(1)
      }

      target.querySelector(".exchange_number").value = index + startingNumber + 1
      target.querySelector(".exchange_number_display").textContent = index + startingNumber + 1

      target.querySelector(".exchange_month_year").textContent = startingRailsDate.monthYear()
      const exchangeDateInput = target.querySelector(".exchange_date")
      exchangeDateInput.value = proposedDate.dateTime()
      this.refreshDatetimeInput(exchangeDateInput)
      target.querySelector(".exchange_month").value = startingRailsDate.month
      target.querySelector(".exchange_year").value = startingRailsDate.year
    })
  }

  refreshDatetimeInput(input) {
    const control = input.closest("[data-controller~='datetime-input']")
    control?.dispatchEvent(new CustomEvent("datetime-input:refresh", { bubbles: true }))
  }

  setExchangeDatetimeReadonly(input, readonly) {
    const control = input.closest("[data-controller~='datetime-input']")
    control?.dispatchEvent(new CustomEvent("datetime-input:readonly", { detail: { readonly }, bubbles: true }))
  }

  _getDueDate() {
    const year = parseInt(document.querySelector(".installment_year").value)
    const month = parseInt(document.querySelector(".installment_month").value)

    return new RailsDate(year, month, 1)
  }

  prevMonth({ target }) {
    this.updateExchangeDate(target, -1)
  }

  nextMonth({ target }) {
    this.updateExchangeDate(target, 1)
  }

  updateReferenceMonthYear(event) {
    const dateInput = event.currentTarget
    const exchangeWrapper = dateInput.closest("[data-entity-transaction-target='exchangeWrapper']")
    const monthYearInput = exchangeWrapper.querySelector(".exchange_month_year")
    const monthInput = exchangeWrapper.querySelector(".exchange_month")
    const yearInput = exchangeWrapper.querySelector(".exchange_year")

    const date = new RailsDate(dateInput.value)

    monthYearInput.textContent = date.monthYear()
    monthInput.value = date.month
    yearInput.value = date.year
  }
}
