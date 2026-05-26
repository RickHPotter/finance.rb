import { Controller } from "@hotwired/stimulus"
import RailsDate from "../models/railsDate"
import { isPresent, sleep } from "../utils/utils.js"
import { _applyMask, _removeMask } from "../utils/mask.js"

// Connects to data-controller="reactive-form"
export default class extends Controller {
  static values = { quickJump: Boolean, type: String }
  static targets = [
    "dateInput", "priceInput",
    "closingDateDay", "daysUntilDueDate",

    "installmentWrapper", "addInstallment", "delInstallment",
    "monthYearInstallment", "priceInstallmentInput", "installmentsCountInput",

    "categoryWrapper", "addCategory",
    "categoryCombobox",
    "categoryColours",

    "entityWrapper",
    "entityCombobox",
    "addEntity",
    "entityIcons",

    "exchangeIntentWrapper",
    "exchangeIntentInput",

    "userCardCombobox",
    "investmentTypeCombobox",
    "monthYearCombobox",
    "monthYearInput",

    "updateButton"
  ]

  connect() {
    this.debounceTimeout = null
    this.advancedFilterChanged = false
    this.quickJumpOverlay = null
    this.quickJumpArmed = false
    this.boundHandleDocumentKeydown = this.handleDocumentKeydown.bind(this)
    this.boundHandleDocumentPointerdown = this.handleDocumentPointerdown.bind(this)

    if (this.element.querySelector("#categories_nested")) {
      this._updateCategories()
    }

    if (this.element.querySelector("#entities_nested")) {
      this._updateEntities()
    }

    this.syncExchangeIntentVisibility()

    if (this.hasPriceInstallmentInputTargets) {
      this._updateInstallmentsPrices()
    }

    if (this.hasCategoryColoursTarget) {
      this.categoryColours = JSON.parse(this.categoryColoursTarget.value)
    }

    if (this.hasEntityIconsTarget) {
      this.entityIcons = JSON.parse(this.entityIconsTarget.value)
    }

    if (this.element.dataset.operationType) {
      this.operationType = this.element.dataset.operationType
    }

    const userCardCombobox = this.hasUserCardComboboxTarget ? this.resolveCombobox(this.userCardComboboxTarget) : null
    const userCardInput = userCardCombobox ? this.selectedComboboxInput(userCardCombobox) : null
    if (userCardInput) {
      this.userCard = parseInt(userCardInput.value)
    }

    if (this.quickJumpEnabled()) {
      document.addEventListener("keydown", this.boundHandleDocumentKeydown, true)
      document.addEventListener("pointerdown", this.boundHandleDocumentPointerdown, true)
    }
  }

  disconnect() {
    if (this.boundHandleDocumentKeydown) {
      document.removeEventListener("keydown", this.boundHandleDocumentKeydown, true)
    }
    if (this.boundHandleDocumentPointerdown) {
      document.removeEventListener("pointerdown", this.boundHandleDocumentPointerdown, true)
    }

    this.clearQuickJumpState()
  }

  clear({ target }) {
    const input = document.getElementById(target.dataset.id)
    if (!input) { return }

    input.value = ""
    input.dispatchEvent(new Event("input"))
  }

  // Installments
  requestSubmitBasedOnUserCardChange({ target }) {
    if (!this.userCard) { return }

    const userCardId = parseInt(target.value)
    if (this.userCard == userCardId) { return }

    this.userCard = target.value
    this.requestSubmit({ target })
  }

  requestSubmit({ target }) {
    const hasValue = isPresent(target.value) || (target.dataset.value && isPresent(target.querySelector(target.dataset.value).value))

    if (hasValue) {
      this.setNextAutofocus(target)
      target.form.requestSubmit(this.updateButtonTarget)
    }
  }

  setNextAutofocus(target) {
    if (!target.dataset.nextAutofocus) { return }

    let input = target.form.querySelector("input[name='next_autofocus']")

    if (!input) {
      input = document.createElement("input")
      input.type = "hidden"
      input.name = "next_autofocus"
      target.form.appendChild(input)
    }

    input.value = target.dataset.nextAutofocus
  }

  updateFullPrice() {
    const visibleInstallmentsInputs = this.priceInstallmentInputTargets.filter((el) => el.checkVisibility())
    let totalPrice = 0

    visibleInstallmentsInputs.forEach((input) => {
      if (input.value) { totalPrice += parseInt(_removeMask(input.value)) }
    })

    this.priceInputTarget.value = _applyMask(totalPrice.toString())
  }

  prevMonth({ target }) {
    this.updateInstallmentDate(target, -1)
  }

  nextMonth({ target }) {
    this.updateInstallmentDate(target, 1)
  }

  updateInstallmentDate(target, count) {
    const installmentWrapper = target.closest("[data-reactive-form-target='installmentWrapper']")
    const monthYearInput = installmentWrapper.querySelector(".installment_month_year")
    const monthInput = installmentWrapper.querySelector(".installment_month")
    const yearInput = installmentWrapper.querySelector(".installment_year")

    const date = new RailsDate(parseInt(yearInput.value), parseInt(monthInput.value), 1)
    date.monthsForwards(count)

    monthYearInput.textContent = date.monthYear()
    monthInput.value = date.month
    yearInput.value = date.year
  }

  async requestSubmitAfterUpdate({ target }) {
    if (target.value < 1) { target.value = 1 }
    if (target.value > 72) { target.value = 72 }

    const installmentsCount = parseInt(this.installmentsCountInputTarget.value)
    await this._updateInstallmentsFields(installmentsCount)

    const hasValue = isPresent(target.value) || (target.dataset.value && isPresent(target.querySelector(target.dataset.value).value))

    if (hasValue) { target.form.requestSubmit(this.updateButtonTarget) }
  }

  updateInstallmentsDates() {
    if (this.dateInputTarget.value === "") { this.dateInputTarget.value = RailsDate.now() }

    const railsDueDate = this._getDueDate()
    this._updateWrappers(railsDueDate, { preserveLocked: true })
  }

  async updateInstallmentsPrices({ target }) {
    if (target.value < 1) { target.value = 1 }
    if (target.value > 72) { target.value = 72 }

    await this._updateInstallmentsPrices()
  }

  updateExchangeWhenDuplicating({ target }) {
    if (this.operationType !== "duplicate") { return }

    const exchangeCategoryInput = this.element.querySelector("#exchange_category_id")
    if (!exchangeCategoryInput) { return }

    const exchangeCategoryId = exchangeCategoryInput.value
    const selectedCategories = Array.from(this.element.querySelectorAll(".categories_category_id"))
    const exchangeCategory   = selectedCategories.find((element) => element.value === exchangeCategoryId)
    if (!exchangeCategory) { return }

    const entityTransactionWrappers = this.element.querySelectorAll("[data-reactive-form-target='entityWrapper']")

    entityTransactionWrappers.forEach((wrapper) => {
      if (wrapper.style.display === "none") { return }
      if (wrapper.querySelector("input[name*='[_destroy]']")?.value === "true") { return }
      if (!wrapper.querySelector(".entities_entity_id")?.value) { return }

      const formIndex         = wrapper.dataset.entityTransactionFormIndex
      const price             = document.getElementById(`entity_transaction_price_${formIndex}`)
      const priceToBeReturned = document.getElementById(`entity_transaction_price_to_be_returned_${formIndex}`)
      const exchangesCount    = document.getElementById(`entity_transaction_exchanges_count_${formIndex}`)
      if (!price || !priceToBeReturned || !exchangesCount) { return }

      const transactionPrice  = this.priceInputTarget.value
      const installmentsCount = this.installmentsCountInputTarget.value

      priceToBeReturned.value = transactionPrice
      priceToBeReturned.dispatchEvent(new Event("input"))

      price.value = transactionPrice
      price.dispatchEvent(new Event("input"))

      exchangesCount.value = installmentsCount
      exchangesCount.dispatchEvent(new Event("input"))
    })
  }

  setPaidIfPastCurrentDay({ target }) {
    if (this.typeValue !== "CashTransaction") { return }

    const thisDate = new RailsDate(target.value)
    const pastCurrentDay = new Date > thisDate.date()

    this.setPaid(target, pastCurrentDay)
  }

  setPaid(target, paid = true) {
    const installmentWrapper = target.closest("[data-reactive-form-target='installmentWrapper']")
    const paidInput = installmentWrapper.querySelector(".installment_paid")
    const installmentPaidColour = installmentWrapper.querySelector(".installment_paid_colour")

    paidInput.checked = paid

    if (paid) {
      installmentPaidColour.classList.add("bg-green-400")
      installmentPaidColour.classList.remove("bg-orange-600")
    } else {
      installmentPaidColour.classList.remove("bg-green-400")
      installmentPaidColour.classList.add("bg-orange-600")
    }
  }

  togglePaid({ target }) {
    const installmentWrapper = target.closest("[data-reactive-form-target='installmentWrapper']")
    const paidInput = installmentWrapper.querySelector(".installment_paid")

    paidInput.checked = !paidInput.checked
    target.classList.toggle("bg-green-400")
    target.classList.toggle("bg-orange-600")
  }

  // Categories
  insertCategory({ target }) {
    const combobox = this.resolveCombobox(target)
    if (!combobox) return console.error("Combobox controller not found")

    let allOptions = this.comboboxOptions(combobox)
    let selectedOption = this.selectedComboboxOption(combobox, target)
    if (!selectedOption) return
    if (this.categoryAlreadySelected(this.comboboxOptionValue(selectedOption))) {
      this.resetComboboxSelection(combobox, selectedOption)
      return
    }

    this._insertCategory(selectedOption)

    this.resetComboboxSelection(combobox, selectedOption)

    let visibleOptions = allOptions.filter((option) => { return !option.classList.contains("hidden") })

    if (visibleOptions.length === 0) {
      this.closeCombobox(combobox)
    } else if (combobox.kind === "hotwire") {
      sleep(() => { this.focusCombobox(combobox) })
    }
  }

  removeCategory({ target }) {
    const wrapper = target.closest("[data-reactive-form-target='categoryWrapper']")
    const chipValue = wrapper.querySelector(".categories_category_id")?.value

    const combobox = this.resolveCombobox(this.hasCategoryComboboxTarget ? this.categoryComboboxTarget : null)
    if (!combobox) return console.error("Combobox controller not found")

    let allOptions = this.comboboxOptions(combobox)
    let removedOption = allOptions.find((option) => { return this.comboboxOptionValue(option) === chipValue })

    if (removedOption) {
      delete removedOption.dataset.comboboxPermanentlyHidden
      removedOption.classList.remove("hidden")
      if (removedOption.dataset.autocompletableAs) {
        removedOption.dataset.filterableAs = removedOption.dataset.autocompletableAs
      }
    }

    wrapper.style.display = "none"
    wrapper.querySelector("input[name*='_destroy']").value = "true"
    this.syncExchangeIntentVisibility()
  }

  // Entities
  insertEntity({ target }) {
    const combobox = this.resolveCombobox(target)
    if (!combobox) return console.error("Combobox controller not found")

    let allOptions = this.comboboxOptions(combobox)
    let selectedOption = this.selectedComboboxOption(combobox, target)
    if (!selectedOption) return
    if (this.entityAlreadySelected(this.comboboxOptionValue(selectedOption))) {
      this.resetComboboxSelection(combobox, selectedOption)
      return
    }

    this._insertEntity(selectedOption)

    this.resetComboboxSelection(combobox, selectedOption)

    let visibleOptions = allOptions.filter((option) => { return !option.classList.contains("hidden") })

    if (visibleOptions.length === 0) {
      this.closeCombobox(combobox)
    } else if (combobox.kind === "hotwire") {
      sleep(() => { this.focusCombobox(combobox) })
    }
  }

  removeEntity({ target }) {
    const wrapper = target.closest("[data-reactive-form-target='entityWrapper']")
    const chipValue = wrapper.querySelector(".entities_entity_id")?.value

    const combobox = this.resolveCombobox(this.hasEntityComboboxTarget ? this.entityComboboxTarget : null)
    if (!combobox) return console.error("Combobox controller not found")

    let allOptions = this.comboboxOptions(combobox)
    let removedOption = allOptions.find((option) => { return this.comboboxOptionValue(option) === chipValue })

    if (removedOption) {
      delete removedOption.dataset.comboboxPermanentlyHidden
      removedOption.classList.remove("hidden")
      if (removedOption.dataset.autocompletableAs) {
        removedOption.dataset.filterableAs = removedOption.dataset.autocompletableAs
      }
    }

    wrapper.style.display = "none"
    wrapper.querySelector("input[name*='_destroy']").value = "true"
  }

  // search
  submitWithDelay(event) {
    clearTimeout(this.debounceTimeout)

    this.debounceTimeout = setTimeout(() => {
      this.element.requestSubmit()
    }, 900)
  }

  submit() {
    this.element.requestSubmit()
  }

  submitIfChanged() {
    if (!this.advancedFilterChanged) return

    this.syncPaidStateFromActiveButton()
    this.advancedFilterChanged = false
    this.element.requestSubmit()
  }

  markChanged() {
    this.advancedFilterChanged = true
  }

  applyPaidState(event) {
    event.preventDefault()

    const { target } = event
    const value = target.dataset.paidStateValue
    if (!value || !this.applyPaidStateValue(target)) return

    this.syncPaidStateButtons(target, value)
    this.advancedFilterChanged = false
    this.element.requestSubmit()
  }

  syncPaidStateFromActiveButton() {
    const activeButton = this.element.querySelector("[data-paid-state-value][aria-pressed='true']")
    if (!activeButton) return

    this.applyPaidStateValue(activeButton)
  }

  applyPaidStateValue(target) {
    const paidStateInput = this.findFormInput(target.dataset.paidStateInputId)
    const paidInput = this.findFormInput(target.dataset.paidInputId)
    const pendingInput = this.findFormInput(target.dataset.pendingInputId)
    const value = target.dataset.paidStateValue
    if (!paidStateInput || !paidInput || !pendingInput || !value) return false

    paidStateInput.value = value

    switch (value) {
      case "paid":
        paidInput.value = "true"
        pendingInput.value = "false"
        break
      case "pending":
        paidInput.value = "false"
        pendingInput.value = "true"
        break
      default:
        paidInput.value = "true"
        pendingInput.value = "true"
    }

    return true
  }

  findFormInput(inputId) {
    if (!inputId) return null

    return this.element.querySelector(`#${inputId}`)
  }

  syncPaidStateButtons(activeButton, value) {
    const buttons = activeButton.parentElement?.querySelectorAll("[data-paid-state-value]")
    if (!buttons) return

    buttons.forEach((button) => {
      const active = button.dataset.paidStateValue === value
      button.setAttribute("aria-pressed", String(active))
      button.classList.toggle("border-blue-700", active)
      button.classList.toggle("bg-blue-100", active)
      button.classList.toggle("text-blue-900", active)
      button.classList.toggle("border-slate-300", !active)
      button.classList.toggle("bg-white", !active)
      button.classList.toggle("text-slate-600", !active)
    })
  }

  // ░▒▓███████▓▒░░▒▓███████▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓██████▓▒░▒▓████████▓▒░▒▓████████▓▒░
  // ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░ ░▒▓█▓▒░   ░▒▓█▓▒
  // ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░ ░▒▓█▓▒░   ░▒▓█▓▒
  // ░▒▓███████▓▒░░▒▓███████▓▒░░▒▓█▓▒░░▒▓█▓▒▒▓█▓▒░░▒▓████████▓▒░ ░▒▓█▓▒░   ░▒▓██████▓▒░
  // ░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░ ░▒▓█▓▓█▓▒░ ░▒▓█▓▒░░▒▓█▓▒░ ░▒▓█▓▒░   ░▒▓█▓▒░
  // ░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░ ░▒▓█▓▓█▓▒░ ░▒▓█▓▒░░▒▓█▓▒░ ░▒▓█▓▒░   ░▒▓█▓▒░
  // ░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░  ░▒▓██▓▒░  ░▒▓█▓▒░░▒▓█▓▒░ ░▒▓█▓▒░   ░▒▓████████▓▒░

  // Installments
  _getDueDate() {
    return new RailsDate(this.element.querySelector(".installment_date").value)
  }

  transactionDateInput() {
    return this.element.querySelector(".transaction-date")
  }

  _updateWrappers(startingRailsDate, { preserveLocked = false } = {}) {
    const visibleInstallmentsWrappers = this.installmentWrapperTargets.filter((element) => element.style.display !== "none")
    const firstVisibleInstallment = visibleInstallmentsWrappers[0]

    if (!firstVisibleInstallment) return

    if (firstVisibleInstallment.querySelector(".installment_month").value) {
      const year = parseInt(firstVisibleInstallment.querySelector(".installment_year").value)
      const month = parseInt(firstVisibleInstallment.querySelector(".installment_month").value)
      const railsDate = new RailsDate(year, month, 1)

      startingRailsDate.setYear(railsDate.year)
      startingRailsDate.setMonth(railsDate.month)
    }

    let proposedDate = new RailsDate(this.transactionDateInput().value)

    visibleInstallmentsWrappers.forEach((target, index) => {
      const locked = preserveLocked && target.dataset.locked === "true"

      target.querySelector(".installment_number").value = index + 1
      target.querySelector(".installment_number_display").textContent = index + 1

      if (locked) {
        proposedDate = new RailsDate(target.querySelector(".installment_date").value)
        startingRailsDate = new RailsDate(
          parseInt(target.querySelector(".installment_year").value, 10),
          parseInt(target.querySelector(".installment_month").value, 10),
          1
        )
      } else {
        target.querySelector(".installment_month_year").textContent = startingRailsDate.monthYear()
        target.querySelector(".installment_date").value = proposedDate.dateTime().length === 15 ? "0" + proposedDate.dateTime() : proposedDate.dateTime()
        target.querySelector(".installment_month").value = startingRailsDate.month
        target.querySelector(".installment_year").value = startingRailsDate.year

        if (target.querySelector("[data-action='click->reactive-form#togglePaid']")) {
          this.setPaidIfPastCurrentDay({ target: target.querySelector(".installment_date") })
        }
      }

      startingRailsDate.monthsForwards(1)
      proposedDate.monthsForwards(1)
    })

    this.element.dispatchEvent(new CustomEvent("installments:layout-changed", { bubbles: true }))
  }

  // FIXME: this way will be a legacy and will serve as a user_card setting
  // async _updateInstallmentsPrices() {
  //   const totalCents = parseInt(_removeMask(this.priceInputTarget.value))
  //   const installmentsCount = parseInt(this.installmentsCountInputTarget.value)
  //
  //   const baseCents = Math.floor(totalCents / installmentsCount)
  //   const remainder = totalCents - baseCents * installmentsCount
  //
  //   await this._updateInstallmentsFields(installmentsCount)
  //
  //   let visibleInstallmentsInputs = this.priceInstallmentInputTargets.filter((el) => el.checkVisibility())
  //   if (baseCents < 0) { visibleInstallmentsInputs = visibleInstallmentsInputs.reverse() }
  //
  //   visibleInstallmentsInputs.forEach((input, index) => {
  //     const valueCents = baseCents + (index < remainder ? 1 : 0)
  //     const value = (valueCents / 100).toFixed(2)
  //     input.value = _applyMask(value)
  //   })
  // }

  async _updateInstallmentsPrices() {
    const totalCents        = parseInt(_removeMask(this.priceInputTarget.value), 10)
    const installmentsCount = parseInt(this.installmentsCountInputTarget.value, 10)

    await this._updateInstallmentsFields(installmentsCount)

    const visibleWrappers = this.installmentWrapperTargets.filter(el => el.style.display !== "none")
    const lockedWrappers = visibleWrappers.filter(el => el.dataset.locked === "true")
    const unlockedWrappers = visibleWrappers.filter(el => el.dataset.locked !== "true")

    let lockedPrice = 0
    lockedWrappers.forEach(wrapper => {
      const priceInput = wrapper.querySelector("[data-reactive-form-target='priceInstallmentInput']")
      if (priceInput) {
        lockedPrice += parseInt(_removeMask(priceInput.value), 10) || 0
      }
    })

    const remainingPrice = totalCents - lockedPrice
    const unlockedCount = unlockedWrappers.length

    if (unlockedCount > 0) {
      const baseCents = remainingPrice >= 0
        ? Math.floor(remainingPrice / unlockedCount)
        : Math.ceil(remainingPrice / unlockedCount)

      const remainder = remainingPrice - baseCents * unlockedCount

      unlockedWrappers.forEach((wrapper, index) => {
        const priceInput = wrapper.querySelector("[data-reactive-form-target='priceInstallmentInput']")
        const valueCents = index === 0 ? (baseCents + remainder) : baseCents
        priceInput.value = _applyMask((valueCents / 100).toFixed(2))
      })
    }
  }

  async _updateInstallmentsFields(newInstallmentsCount) {
    const allInstallments = this.priceInstallmentInputTargets
    const allInstallmentsCount = allInstallments.length
    const visibleInstallments = allInstallments.filter((element) => element.checkVisibility())
    const visibleInstallmentsCount = visibleInstallments.length

    const shouldRemoveInstallments = newInstallmentsCount < visibleInstallmentsCount
    const shouldAddInstallments = newInstallmentsCount > visibleInstallmentsCount
    const canUpdateHiddenInstallments = allInstallmentsCount > visibleInstallmentsCount

    if (visibleInstallmentsCount === newInstallmentsCount) { return }

    if (shouldRemoveInstallments) {
      const installmentsDeleteButtonsToBeClicked = this.delInstallmentTargets.slice(newInstallmentsCount)

      installmentsDeleteButtonsToBeClicked.forEach((element) => element.click())
    }

    if (shouldAddInstallments) {
      if (canUpdateHiddenInstallments) {
        const sliced = this.installmentWrapperTargets.slice(visibleInstallmentsCount, newInstallmentsCount)

        sliced.forEach(element => {
          element.style.display = "block"
          element.querySelector("input[name*='_destroy']").value = "false"
        })
      }

      const numberOfNewInstallmentsToAdd = newInstallmentsCount - allInstallmentsCount
      for (let i = 0; i < numberOfNewInstallmentsToAdd; i++) {
        await new Promise((resolve) => setTimeout(resolve, 50))
        this.addInstallmentTarget.click()
      }
    }

    const railsDueDate = this._getDueDate()
    this._updateWrappers(railsDueDate, { preserveLocked: true })
  }

  // Categories
  _insertCategory(selectedOption) {
    selectedOption.dataset.comboboxPermanentlyHidden = "true"
    selectedOption.classList.add("hidden")
    if (selectedOption.dataset.filterableAs !== undefined) {
      selectedOption.dataset.filterableAs = ""
    }

    const value = this.comboboxOptionValue(selectedOption)
    const text = this.comboboxOptionText(selectedOption)

    this.addCategoryTarget.click()

    const wrappers = this.categoryWrapperTargets
    const newWrapper = wrappers[wrappers.length - 1]

    newWrapper.querySelector(".category_container").style.backgroundColor = this.categoryColours[value]
    newWrapper.querySelector(".categories_category_id").value = value
    newWrapper.querySelector(".categories_category_name").textContent = text
    this.syncExchangeIntentVisibility()
  }

  _insertExchangeCategory() {
    const exchangeCategoryId = this.element.querySelector("#exchange_category_id").value
    const exchangeCategoryName = this.element.querySelector("#exchange_category_name").value
    const value = exchangeCategoryId
    const text = exchangeCategoryName

    const selectedCategories = Array.from(document.querySelectorAll(".categories_category_id"))
    const exchangeCategory = selectedCategories.find((element) => element.value === value)
    if (exchangeCategory) {
      const categoryWrapperDiv = this.categoryWrapperTargets.find((element) => element.querySelector(".categories_category_name").textContent === text)

      if (!categoryWrapperDiv) return

      categoryWrapperDiv.style.display = "block"
      categoryWrapperDiv.querySelector("input[name*='_destroy']").value = "false"
      this.syncExchangeIntentVisibility()

      return
    }

    this.addCategoryTarget.click()

    const wrappers = this.categoryWrapperTargets
    const newWrapper = wrappers[wrappers.length - 1]

    newWrapper.querySelector(".category_container").style.backgroundColor = this.categoryColours[value]
    newWrapper.querySelector(".categories_category_id").value = value
    newWrapper.querySelector(".categories_category_name").textContent = text
    this.syncExchangeIntentVisibility()
  }

  _removeExchangeCategory() {
    const exchangeCategoryName = this.element.querySelector("#exchange_category_name").value
    const categoryWrapperDiv = this.categoryWrapperTargets.find((element) => element.querySelector(".categories_category_name").textContent === exchangeCategoryName)

    if (!categoryWrapperDiv) return

    categoryWrapperDiv.style.display = "none"
    categoryWrapperDiv.querySelector("input[name*='_destroy']").value = "true"
    this.syncExchangeIntentVisibility()
  }

  syncExchangeIntentVisibility() {
    if (!this.hasExchangeIntentWrapperTarget || !this.hasExchangeIntentInputTarget) { return }

    const exchangeCategoryId = this.element.querySelector("#exchange_category_id")?.value
    const hasExchangeCategory = this.categoryWrapperTargets.some((wrapper) => {
      const input = wrapper.querySelector(".categories_category_id")
      const destroyInput = wrapper.querySelector("input[name*='_destroy']")

      return input?.value === exchangeCategoryId && destroyInput?.value !== "true" && wrapper.checkVisibility()
    })

    this.exchangeIntentWrapperTarget.classList.toggle("hidden", !hasExchangeCategory)

    if (!hasExchangeCategory) {
      this.exchangeIntentInputTarget.value = "loan"
      return
    }

    if (!this.exchangeIntentInputTarget.value) {
      this.exchangeIntentInputTarget.value = "loan"
    }
  }

  _updateCategories() {
    // NOTE: sleeping here is due to the fact that the combobox controller is initialised AFTER reactive-form controller
    sleep(() => {
      const combobox = this.resolveCombobox(this.hasCategoryComboboxTarget ? this.categoryComboboxTarget : null)
      if (!combobox) return console.error("Combobox controller not found")

      const chipValues = this.categoryWrapperTargets.map((target) => { return target.querySelector(".categories_category_id").value })

      let allOptions = this.comboboxOptions(combobox)
      let toBeHidden = allOptions.filter((option) => { return chipValues.includes(this.comboboxOptionValue(option)) })

      toBeHidden.forEach((option) => {
        option.dataset.comboboxPermanentlyHidden = "true"
        option.classList.add("hidden")
        if (option.dataset.filterableAs !== undefined) {
          option.dataset.filterableAs = ""
        }
      })
    })
  }

  // Entities

  categoryAlreadySelected(value) {
    return this.categoryWrapperTargets.some((wrapper) => {
      const input = wrapper.querySelector(".categories_category_id")
      const destroyInput = wrapper.querySelector("input[name*='_destroy']")

      return input?.value === value && destroyInput?.value !== "true" && wrapper.checkVisibility()
    })
  }

  _insertEntity(selectedOption) {
    selectedOption.dataset.comboboxPermanentlyHidden = "true"
    selectedOption.classList.add("hidden")
    if (selectedOption.dataset.filterableAs !== undefined) {
      selectedOption.dataset.filterableAs = ""
    }

    const value = this.comboboxOptionValue(selectedOption)
    const text = this.comboboxOptionText(selectedOption)

    this.addEntityTarget.click()

    const wrappers = this.entityWrapperTargets
    const newWrapper = wrappers[wrappers.length - 1]

    newWrapper.querySelector(".entities_entity_id").value = value
    newWrapper.querySelectorAll(".entities_entity_name").forEach((element) => { element.textContent = text })

    const avatarImage = document.createElement("img")
    avatarImage.src = this.entityIcons[value]
    avatarImage.classList.add("entity_avatar", "w-6", "h-6", "rounded-full")
    newWrapper.querySelector(".entity_avatar_container").prepend(avatarImage)
  }

  _updateEntities() {
    // NOTE: sleeping here is due to the fact that the combobox controller is initialised AFTER reactive-form controller
    sleep(() => {
      const combobox = this.resolveCombobox(this.hasEntityComboboxTarget ? this.entityComboboxTarget : null)
      if (!combobox) return console.error("Combobox controller not found")

      const chipValues = this.entityWrapperTargets.map((target) => { return target.querySelector(".entities_entity_id").value })

      let allOptions = this.comboboxOptions(combobox)
      let toBeHidden = allOptions.filter((option) => { return chipValues.includes(this.comboboxOptionValue(option)) })

      toBeHidden.forEach((option) => {
        option.dataset.comboboxPermanentlyHidden = "true"
        option.classList.add("hidden")
        if (option.dataset.filterableAs !== undefined) {
          option.dataset.filterableAs = ""
        }
      })
    })
  }

  entityAlreadySelected(value) {
    return this.entityWrapperTargets.some((wrapper) => {
      const input = wrapper.querySelector(".entities_entity_id")
      const destroyInput = wrapper.querySelector("input[name*='_destroy']")

      return input?.value === value && destroyInput?.value !== "true" && wrapper.checkVisibility()
    })
  }

  resolveCombobox(target) {
    if (!target) { return null }

    const root =
      (target.matches?.("[data-controller~='ruby-ui--combobox']") ? target : null) ||
      target.querySelector?.("[data-controller~='ruby-ui--combobox']") ||
      target.closest?.("[data-controller~='ruby-ui--combobox']")
    if (!root) { return null }

    const controller = this.application.getControllerForElementAndIdentifier(root, "ruby-ui--combobox")
    return controller ? { controller, root } : null
  }

  comboboxOptions(combobox) {
    return combobox.controller.itemTargets
  }

  selectedComboboxOption(combobox, target) {
    return target.closest("[data-ruby-ui--combobox-target='item']") || this.checkedComboboxOption(combobox)
  }

  checkedComboboxOption(combobox) {
    return this.comboboxOptions(combobox).find((option) => option.querySelector("input:checked"))
  }

  selectedComboboxInput(combobox) {
    return this.checkedComboboxOption(combobox)?.querySelector("input") || null
  }

  comboboxOptionValue(option) {
    return option.dataset.value || option.querySelector("input")?.value
  }

  comboboxOptionText(option) {
    const input = option.querySelector("input")
    return input?.dataset.text || option.textContent.trim()
  }

  resetComboboxSelection(combobox, selectedOption) {
    const input = selectedOption.querySelector("input")
    if (input) {
      input.checked = false
    }

    if (combobox.controller.hasSearchInputTarget) {
      combobox.controller.searchInputTarget.value = ""
      combobox.controller.filterItems({ key: null })
    }

    combobox.controller.updateTriggerContent()
  }

  closeCombobox(combobox) {
    combobox.controller.closePopover()
  }

  focusCombobox(combobox) {
    combobox.controller.triggerTarget.focus()
  }

  handleDocumentKeydown(event) {
    if (!this.quickJumpEnabled()) { return }
    if (event.metaKey || event.ctrlKey || event.altKey) { return }

    const activeElement = document.activeElement
    const eventInsideForm = this.element.contains(event.target) || this.element.contains(activeElement)
    if (!eventInsideForm) { return }

    if (event.key === "Escape") {
      event.preventDefault()
      event.stopPropagation()
      this.showQuickJumpState()
      return
    }

    if (!this.quickJumpArmed) { return }
    if (event.key.toLowerCase() === "d") {
      event.preventDefault()
      event.stopPropagation()
      this.toggleDuplicateChain()
      this.clearQuickJumpState()
      return
    }

    if (!/^[1-9]$/.test(event.key)) {
      this.clearQuickJumpState()
      return
    }

    const field = this.quickJumpFields()[parseInt(event.key, 10) - 1]
    event.preventDefault()
    event.stopPropagation()

    if (!field) {
      this.clearQuickJumpState()
      return
    }

    this.focusQuickJumpField(field)
  }

  quickJumpEnabled() {
    return this.quickJumpValue || this.element.id === "transaction_form"
  }

  showQuickJumpState() {
    const fields = this.quickJumpFields()
    if (fields.length === 0) { return }
    this.quickJumpArmed = true
    window.__reactiveFormQuickJumpActive = true

    if (!this.quickJumpOverlay) {
      this.quickJumpOverlay = document.createElement("div")
      this.quickJumpOverlay.className = "fixed inset-x-0 bottom-4 z-50 mx-auto w-fit max-w-[calc(100vw-2rem)] rounded-2xl border border-slate-700 bg-slate-950/95 px-4 py-3 text-xs shadow-2xl ring-1 ring-slate-800 backdrop-blur-md"
      this.quickJumpOverlay.setAttribute("aria-live", "polite")
      this.quickJumpOverlay.setAttribute("role", "status")
      document.body.appendChild(this.quickJumpOverlay)
    }

    this.quickJumpOverlay.innerHTML = `
      <div class="mb-2 flex items-center gap-2 border-b border-slate-800 pb-2">
        <span class="rounded-md border border-amber-400/60 bg-amber-300/10 px-2 py-0.5 font-mono text-[11px] font-semibold tracking-wide text-amber-200">ESC</span>
        <span class="text-[11px] font-medium uppercase tracking-[0.18em] text-slate-400">Quick Jump</span>
      </div>
      <div class="flex flex-wrap gap-2 text-slate-200">
        ${fields.map((field, index) => `
          <span class="flex items-center gap-2 rounded-lg border border-slate-800 bg-slate-900/80 px-2.5 py-1.5">
            <span class="rounded-md border border-sky-400/40 bg-sky-300/10 px-1.5 py-0.5 font-mono text-[11px] font-semibold text-sky-200">${index + 1}</span>
            <span class="text-[11px] font-medium tracking-wide text-slate-100">${field.label}</span>
          </span>
        `).join("")}
        ${this.continueChainInput() ? `
          <span class="flex items-center gap-2 rounded-lg border border-slate-800 bg-slate-900/80 px-2.5 py-1.5">
            <span class="rounded-md border border-violet-400/40 bg-violet-300/10 px-1.5 py-0.5 font-mono text-[11px] font-semibold text-violet-200">D</span>
            <span class="text-[11px] font-medium tracking-wide text-slate-100">${this.duplicateLabel()}</span>
          </span>
        ` : ""}
      </div>
    `
  }

  clearQuickJumpState() {
    this.quickJumpArmed = false
    window.__reactiveFormQuickJumpActive = false

    if (this.quickJumpOverlay) {
      this.quickJumpOverlay.remove()
      this.quickJumpOverlay = null
    }
  }

  handleDocumentPointerdown(event) {
    if (!this.quickJumpOverlay) { return }
    if (this.quickJumpOverlay.contains(event.target)) { return }

    this.clearQuickJumpState()
  }

  quickJumpFields() {
    if (this.element.id === "investment_form") return this.investmentQuickJumpFields()
    if (this.element.querySelector("#budget_description")) return this.budgetQuickJumpFields()

    return [
      this.quickJumpTextField("#card_transaction_description, #cash_transaction_description", this.descriptionLabel()),
      this.quickJumpTextField("#card_transaction_comment, #cash_transaction_comment", this.commentLabel()),
      this.quickJumpCombobox(this.hasUserCardComboboxTarget ? this.userCardComboboxTarget : this.element.querySelector("#cash_transaction_user_bank_account_combobox"), this.accountLabel()),
      this.quickJumpCombobox(this.hasCategoryComboboxTarget ? this.categoryComboboxTarget : null, this.categoryLabel()),
      this.quickJumpCombobox(this.hasEntityComboboxTarget ? this.entityComboboxTarget : null, this.entityLabel()),
      this.quickJumpDateField(),
      this.quickJumpTimeField(),
      this.quickJumpField(this.hasPriceInputTarget ? this.priceInputTarget : null, this.priceLabel()),
      this.quickJumpField(this.hasInstallmentsCountInputTarget ? this.installmentsCountInputTarget : null, this.installmentsLabel()),
      this.quickJumpField(this.exchangeIntentElement(), this.exchangeIntentLabel())
    ].filter(Boolean)
  }

  investmentQuickJumpFields() {
    return [
      this.quickJumpTextField("#investment_description", this.descriptionLabel()),
      this.quickJumpCombobox(this.element.querySelector("#investment_user_bank_account_combobox"), this.accountLabel()),
      this.quickJumpCombobox(this.hasInvestmentTypeComboboxTarget ? this.investmentTypeComboboxTarget : null, this.investmentTypeLabel()),
      this.quickJumpField(this.hasDateInputTarget ? this.dateInputTarget : null, this.dateLabel()),
      this.quickJumpField(this.hasPriceInputTarget ? this.priceInputTarget : null, this.priceLabel())
    ].filter(Boolean)
  }

  budgetQuickJumpFields() {
    return [
      this.quickJumpTextField("#budget_description", this.descriptionLabel()),
      this.quickJumpCombobox(this.hasCategoryComboboxTarget ? this.categoryComboboxTarget : null, this.categoryLabel()),
      this.quickJumpCombobox(this.hasEntityComboboxTarget ? this.entityComboboxTarget : null, this.entityLabel()),
      this.quickJumpCombobox(this.hasMonthYearComboboxTarget ? this.monthYearComboboxTarget : null, this.monthYearLabel()) ||
        this.quickJumpField(this.hasMonthYearInputTarget ? this.monthYearInputTarget : null, this.monthYearLabel()),
      this.quickJumpField(this.hasPriceInputTarget ? this.priceInputTarget : null, this.priceLabel())
    ].filter(Boolean)
  }

  quickJumpTextField(selector, fallbackLabel) {
    const element = this.element.querySelector(selector)
    return this.quickJumpField(element, element?.dataset?.text || element?.placeholder || fallbackLabel)
  }

  quickJumpCombobox(target, fallbackLabel) {
    const combobox = this.resolveCombobox(target)
    if (!combobox) { return null }

    const label = combobox.controller.triggerTarget?.dataset?.placeholder || fallbackLabel
    return {
      label,
      focus: () => this.focusCombobox(combobox)
    }
  }

  quickJumpDateField() {
    const visibleDateInput = this.hasDateInputTarget ? this.element.querySelector(`#${this.dateInputTarget.id}_date_input`) : null
    const label = visibleDateInput?.ariaLabel || visibleDateInput?.getAttribute("aria-label") || this.dateLabel()
    return this.quickJumpField(visibleDateInput, label)
  }

  quickJumpTimeField() {
    const visibleTimeInput = this.hasDateInputTarget ? this.element.querySelector(`#${this.dateInputTarget.id}_time_input`) : null
    const label = visibleTimeInput?.ariaLabel || visibleTimeInput?.getAttribute("aria-label") || this.timeLabel()
    return this.quickJumpField(visibleTimeInput, label)
  }

  quickJumpField(element, label) {
    if (!element || !element.checkVisibility()) { return null }
    if (element.disabled) { return null }

    return {
      label,
      focus: () => this.focusElement(element)
    }
  }

  focusQuickJumpField(field) {
    this.clearQuickJumpState()
    field.focus()
  }

  focusElement(element) {
    element.focus()

    if (["INPUT", "TEXTAREA"].includes(element.tagName) && element.select) {
      const valueLength = element.value?.length || 0
      if (this.supportsSelectionRange(element)) {
        element.setSelectionRange(valueLength, valueLength)
      }
      element.select()
    }
  }

  supportsSelectionRange(element) {
    if (element.tagName === "TEXTAREA") { return true }
    if (element.tagName !== "INPUT") { return false }

    return !["date", "time", "datetime-local", "month", "week", "color", "number"].includes(element.type)
  }

  exchangeIntentElement() {
    if (!this.hasExchangeIntentInputTarget) { return null }
    if (!this.hasExchangeIntentWrapperTarget || !this.exchangeIntentWrapperTarget.checkVisibility()) { return null }

    return this.exchangeIntentInputTarget
  }

  descriptionLabel() {
    return "description"
  }

  commentLabel() {
    return "comment"
  }

  accountLabel() {
    return this.hasUserCardComboboxTarget ? "card" : "account"
  }

  categoryLabel() {
    return "category"
  }

  entityLabel() {
    return "entity"
  }

  dateLabel() {
    return "date"
  }

  timeLabel() {
    return "time"
  }

  priceLabel() {
    return "price"
  }

  installmentsLabel() {
    return "installments"
  }

  investmentTypeLabel() {
    return "investment type"
  }

  monthYearLabel() {
    return "month/year"
  }

  exchangeIntentLabel() {
    return "intent"
  }

  duplicateLabel() {
    return "duplicate more"
  }

  continueChainInput() {
    const input = this.element.querySelector("input[name='continue_chain']")
    if (!input || !input.checkVisibility() || input.disabled) { return null }

    return input
  }

  toggleDuplicateChain() {
    const input = this.continueChainInput()
    if (!input) { return }

    input.checked = !input.checked
    input.dispatchEvent(new Event("input", { bubbles: true }))
    input.dispatchEvent(new Event("change", { bubbles: true }))
  }
}
