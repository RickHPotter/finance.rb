import { Controller } from "@hotwired/stimulus"
import { initModals } from "flowbite"
import RailsDate from "../models/railsDate"
import { sleep } from "../utils/utils.js"
import { _removeMask, _applyMask } from "../utils/mask.js"

// TODO: this is almost a total copy-paste from reactive-form-controller, i will deal with this after it is working
export default class extends Controller {
  static targets = [
    "button", "dateInput", "priceInput", "priceToBeReturnedInput", "priceExchangeInput", "exchangesCountInput", "exchangesCountEqualsButton",
    "boundType", "exchangeWrapper", "monthYearExchange", "addExchange", "delExchange"
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
        this.delExchangeTargets.forEach((element) => element.click())
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

    if (Math.abs(priceToBeReturned) > Math.abs(price)) { this.priceInputTarget.value = this._applyMask(priceToBeReturned.toString()) }
    this._addBorderToPriceInputs(totalPrice)
    await this._updateExchangesPrices()
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

    if (target.value == "card_bound") {
      this.element.querySelectorAll(".exchange_date").forEach((element) => element.readOnly = true)

      this.monthYearExchangeTarget.textContent = ""
      const railsDueDate = this._getDueDate()
      this._updateWrappers(railsDueDate, 0)

      const prevMonthTarget = this.element.querySelector("[data-entity-transaction-target='button']")
      this.updateExchangeDate(prevMonthTarget, 0)
    } else {
      this.element.querySelectorAll(".exchange_date").forEach((element) => element.readOnly = false)
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

    const visibleExchanges = this.exchangeWrapperTargets.filter((element) => element.style.display !== "none")
    const lockedExchanges = visibleExchanges.filter(e => e.dataset.locked === "true")
    const unlockedExchanges = visibleExchanges.filter(e => e.dataset.locked !== "true")

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

    let railsDueDate
    const currentVisibleExchanges = this.exchangeWrapperTargets.filter((element) => element.style.display !== "none")

    if (visibleExchangesCount > 0) {
        const lastExchange = currentVisibleExchanges[visibleExchangesCount - 1]
        const month = parseInt(lastExchange.querySelector(".exchange_month").value)
        const year = parseInt(lastExchange.querySelector(".exchange_year").value)
        railsDueDate = new RailsDate(year, month, 1)
    } else {
        railsDueDate = this._getDueDate()
    }

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

    this._updateWrappers(railsDueDate, visibleExchangesCount)
  }

  _updateWrappers(startingRailsDate, startingNumber = 0) {
    const visibleExchangesWrappers = this.exchangeWrapperTargets.filter((element) => element.style.display !== "none")
    if (visibleExchangesWrappers.length === 0) { return }

    let proposedDate
    if (startingNumber > 0) {
      const prevExchange = visibleExchangesWrappers[startingNumber - 1]
      const dateValue = prevExchange.querySelector(".exchange_date").value
      proposedDate = new RailsDate(dateValue)
    } else {
      proposedDate = new RailsDate(document.querySelector("#cash_transaction_date").value)
      proposedDate.setHour(0)
      proposedDate.setMinute(0)
    }

    startingRailsDate.monthsForwards(startingNumber)
    proposedDate.monthsForwards(startingNumber)

    visibleExchangesWrappers.slice(startingNumber).forEach((target, index) => {
      if (index > 0) {
        startingRailsDate.monthsForwards(1)
        proposedDate.monthsForwards(1)
      }

      target.querySelector(".exchange_month_year").textContent = startingRailsDate.monthYear()
      target.querySelector(".exchange_date").value = proposedDate.dateTime()
      target.querySelector(".exchange_month").value = startingRailsDate.month
      target.querySelector(".exchange_year").value = startingRailsDate.year
      target.querySelector(".exchange_number").value = index + startingNumber + 1
    })
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
