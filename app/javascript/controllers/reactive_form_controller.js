import { Controller } from "@hotwired/stimulus"
import RailsDate from "../models/railsDate"
import { isPresent, sleep } from "../utils/utils.js"
import { _applyMask, _removeMask } from "../utils/mask.js"

// Connects to data-controller="reactive-form"
export default class extends Controller {
  static values = { type: String }
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

    "updateButton"
  ]

  connect() {
    this.debounceTimeout = null

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

    if (hasValue) { target.form.requestSubmit(this.updateButtonTarget) }
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
    this._updateWrappers(railsDueDate)
  }

  async updateInstallmentsPrices({ target }) {
    if (target.value < 1) { target.value = 1 }
    if (target.value > 72) { target.value = 72 }

    await this._updateInstallmentsPrices()
  }

  updateExchangeWhenDuplicating({ target }) {
    if (this.operationType !== "duplicate") { return }

    const exchangeCategoryId = this.element.querySelector("#exchange_category_id").value
    const selectedCategories = Array.from(document.querySelectorAll(".categories_category_id"))
    const exchangeCategory   = selectedCategories.find((element) => element.value === exchangeCategoryId)
    if (!exchangeCategory) { return }

    const entityTransactionWrappers = this.element.querySelectorAll("[data-controller='entity-transaction']")

    entityTransactionWrappers.forEach((wrapper) => {
      if (wrapper.style.display === "none") { return }
      if (wrapper.querySelector("input[name*='[_destroy]']")?.value === "true") { return }
      if (!wrapper.querySelector(".entities_entity_id")?.value) { return }

      const price             = wrapper.querySelector("[data-entity-transaction-target='priceInput']")
      const priceToBeReturned = wrapper.querySelector("[data-entity-transaction-target='priceToBeReturnedInput']")
      const exchangesCount    = wrapper.querySelector("[data-entity-transaction-target='exchangesCountInput']")

      if (parseInt(_removeMask(price.value)) === 0) { return }
      if (parseInt(_removeMask(priceToBeReturned.value)) === 0) { return }

      price.value = this.priceInputTarget.value
      price.dispatchEvent(new Event("input"))

      priceToBeReturned.value = this.priceInputTarget.value
      priceToBeReturned.dispatchEvent(new Event("input"))

      exchangesCount.value = this.installmentsCountInputTarget.value
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

    let proposedDate = new RailsDate(document.querySelector(".transaction-date").value)

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
}
