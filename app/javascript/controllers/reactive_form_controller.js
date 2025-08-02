import { Controller } from "@hotwired/stimulus"
import RailsDate from "../models/railsDate"
import { isPresent, sleep } from "../utils/utils.js"
import { _applyMask, _removeMask } from "../utils/mask.js"

// Connects to data-controller="reactive-form"
export default class extends Controller {
  static targets = [
    "dateInput", "priceInput",
    "closingDateDay", "daysUntilDueDate",

    "installmentWrapper", "addInstallment", "delInstallment",
    "monthYearInstallment", "priceInstallmentInput", "installmentsCountInput",

    "categoryWrapper", "addCategory",
    "categoryColours",

    "entityWrapper",
    "addEntity",
    "entityIcons",

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

    if (this.hasPriceInstallmentInputTargets) {
      this._updateInstallmentsPrices()
    }

    if (this.hasCategoryColoursTarget) {
      this.categoryColours = JSON.parse(this.categoryColoursTarget.value)
    }

    if (this.hasEntityIconsTarget) {
      this.entityIcons = JSON.parse(this.entityIconsTarget.value)
    }
  }

  clear({ target }) {
    const input = document.getElementById(target.dataset.id)
    if (!input) { return }

    input.value = ""
    input.dispatchEvent(new Event("input"))
  }

  // Installments
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
    if (this.dateInputTarget.value === "") { this.dateInputTarget.value = RailsDate.today().toISOString().slice(0, 16) }

    const railsDueDate = this._getDueDate()
    this._updateWrappers(railsDueDate)
  }

  async updateInstallmentsPrices({ target }) {
    if (target.value < 1) { target.value = 1 }
    if (target.value > 72) { target.value = 72 }

    await this._updateInstallmentsPrices()
  }

  setPaid({ target }) {
    const installmentWrapper = target.closest("[data-reactive-form-target='installmentWrapper']")
    const paidInput = installmentWrapper.querySelector(".installment_paid")

    paidInput.checked = !paidInput.checked
    target.classList.toggle("bg-green-400")
    target.classList.toggle("bg-orange-600")
  }

  // Categories
  insertCategory({ target }) {
    const comboboxController = this.application.getControllerForElementAndIdentifier(target, "hw-combobox")
    if (!comboboxController) return console.error("Combobox controller not found")

    let allOptions = comboboxController._allOptions
    let selectedOption = comboboxController._selectedOptionElement
    if (!selectedOption) return

    this._insertCategory(selectedOption)

    comboboxController.clearOrToggleOnHandleClick()

    let visibleOptions = allOptions.filter((option) => { return !option.classList.contains("hidden") })

    if (visibleOptions.length === 0) {
      comboboxController.close()
    } else {
      sleep(() => { comboboxController.actingCombobox.focus() })
    }
  }

  removeCategory({ target }) {
    const wrapper = target.closest("[data-reactive-form-target='categoryWrapper']")
    const chipValue = wrapper.querySelector(".categories_category_id")?.value

    const combobox = this.element.querySelector("#hw_category_id .hw-combobox")
    const comboboxController = this.application.getControllerForElementAndIdentifier(combobox, "hw-combobox")
    if (!comboboxController) return console.error("Combobox controller not found")

    let allOptions = comboboxController._allOptions
    let removedOption = allOptions.find((option) => { return option.dataset.value === chipValue })

    if (removedOption) {
      removedOption.classList.remove("hidden")
      removedOption.dataset.filterableAs = removedOption.dataset.autocompletableAs
    }

    wrapper.style.display = "none"
    wrapper.querySelector("input[name*='_destroy']").value = "true"
  }

  // Entities
  insertEntity({ target }) {
    const comboboxController = this.application.getControllerForElementAndIdentifier(target, "hw-combobox")
    if (!comboboxController) return console.error("Combobox controller not found")

    let allOptions = comboboxController._allOptions
    let selectedOption = comboboxController._selectedOptionElement
    if (!selectedOption) return

    this._insertEntity(selectedOption)

    comboboxController.clearOrToggleOnHandleClick()

    let visibleOptions = allOptions.filter((option) => { return !option.classList.contains("hidden") })

    if (visibleOptions.length === 0) {
      comboboxController.close()
    } else {
      sleep(() => { comboboxController.actingCombobox.focus() })
    }
  }

  removeEntity({ target }) {
    const wrapper = target.closest("[data-reactive-form-target='entityWrapper']")
    const chipValue = wrapper.querySelector(".entities_entity_id")?.value

    const combobox = this.element.querySelector("#hw_entity_id .hw-combobox")
    const comboboxController = this.application.getControllerForElementAndIdentifier(combobox, "hw-combobox")
    if (!comboboxController) return console.error("Combobox controller not found")

    let allOptions = comboboxController._allOptions
    let removedOption = allOptions.find((option) => { return option.dataset.value === chipValue })

    if (removedOption) {
      removedOption.classList.remove("hidden")
      removedOption.dataset.filterableAs = removedOption.dataset.autocompletableAs
    }

    wrapper.style.display = "none"
    wrapper.querySelector("input[name*='_destroy']").value = "true"
  }

  // search
  submitWithDelay() {
    clearTimeout(this.debounceTimeout)

    this.debounceTimeout = setTimeout(() => {
      this.element.requestSubmit()
    }, 800)
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

  _updateWrappers(startingRailsDate) {
    const visibleInstallmentsWrappers = this.installmentWrapperTargets.filter((element) => element.checkVisibility())
    const firstVisibleInstallment = visibleInstallmentsWrappers[0]

    if (!firstVisibleInstallment) return

    if (firstVisibleInstallment.querySelector(".installment_month").value) {
      const year = parseInt(firstVisibleInstallment.querySelector(".installment_year").value)
      const month = parseInt(firstVisibleInstallment.querySelector(".installment_month").value)
      const railsDate = new RailsDate(year, month, 1)

      startingRailsDate.setYear(railsDate.year)
      startingRailsDate.setMonth(railsDate.month)
    }

    visibleInstallmentsWrappers.forEach((target, index) => {

      target.querySelector(".installment_number").value = index + 1

      const [ year, month, day ] = document.querySelector(".transaction-date").value.slice(0, 10).split("-").map(Number)
      const proposedDate = new RailsDate(year, month, day)
      proposedDate.monthsForwards(index)

      target.querySelector(".installment_month_year").textContent = startingRailsDate.monthYear()
      target.querySelector(".installment_date").value = proposedDate.dateTime()
      target.querySelector(".installment_month").value = startingRailsDate.month
      target.querySelector(".installment_year").value = startingRailsDate.year

      startingRailsDate.monthsForwards(1)
      proposedDate.monthsForwards(1)
    })
  }

  async _updateInstallmentsPrices() {
    const totalCents = parseInt(_removeMask(this.priceInputTarget.value))
    const installmentsCount = parseInt(this.installmentsCountInputTarget.value)

    const baseCents = Math.floor(totalCents / installmentsCount)
    const remainder = totalCents - baseCents * installmentsCount

    await this._updateInstallmentsFields(installmentsCount)

    let visibleInstallmentsInputs = this.priceInstallmentInputTargets.filter((el) => el.checkVisibility())
    if (baseCents < 0) { visibleInstallmentsInputs = visibleInstallmentsInputs.reverse() }

    visibleInstallmentsInputs.forEach((input, index) => {
      const valueCents = baseCents + (index < remainder ? 1 : 0)
      const value = (valueCents / 100).toFixed(2)
      input.value = _applyMask(value)
    })
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
    this._updateWrappers(railsDueDate)
  }

  // Categories
  _insertCategory(selectedOption) {
    selectedOption.classList.add("hidden")
    selectedOption.dataset.filterableAs = ""

    const value = selectedOption.dataset.value
    const text = selectedOption.textContent

    this.addCategoryTarget.click()

    const wrappers = this.categoryWrapperTargets
    const newWrapper = wrappers[wrappers.length - 1]

    newWrapper.querySelector(".category_container").classList.add(this.categoryColours[value])
    newWrapper.querySelector(".categories_category_id").value = value
    newWrapper.querySelector(".categories_category_name").textContent = text
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

      return
    }

    this.addCategoryTarget.click()

    const wrappers = this.categoryWrapperTargets
    const newWrapper = wrappers[wrappers.length - 1]

    newWrapper.querySelector(".category_container").classList.add(this.categoryColours[value])
    newWrapper.querySelector(".categories_category_id").value = value
    newWrapper.querySelector(".categories_category_name").textContent = text
  }

  _removeExchangeCategory() {
    const exchangeCategoryName = this.element.querySelector("#exchange_category_name").value
    const categoryWrapperDiv = this.categoryWrapperTargets.find((element) => element.querySelector(".categories_category_name").textContent === exchangeCategoryName)

    if (!categoryWrapperDiv) return

    categoryWrapperDiv.style.display = "none"
    categoryWrapperDiv.querySelector("input[name*='_destroy']").value = "true"
  }

  _updateCategories() {
    // NOTE: sleeping here is due to the fact that the combobox controller is initialised AFTER reactive-form controller
    sleep(() => {
      const combobox = this.element.querySelector("#hw_category_id .hw-combobox")
      const comboboxController = this.application.getControllerForElementAndIdentifier(combobox, "hw-combobox")
      if (!comboboxController) return console.error("Combobox controller not found")

      const chipValues = this.categoryWrapperTargets.map((target) => { return target.querySelector(".categories_category_id").value })

      let allOptions = comboboxController._allOptions
      let toBeHidden = allOptions.filter((option) => { return chipValues.includes(option.dataset.value) })

      toBeHidden.forEach((option) => {
        option.classList.add("hidden")
        option.dataset.filterableAs = ""
      })
    })
  }

  // Entities

  _insertEntity(selectedOption) {
    selectedOption.classList.add("hidden")
    selectedOption.dataset.filterableAs = ""

    const value = selectedOption.dataset.value
    const text = selectedOption.textContent

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
      const combobox = this.element.querySelector("#hw_entity_id .hw-combobox")
      const comboboxController = this.application.getControllerForElementAndIdentifier(combobox, "hw-combobox")
      if (!comboboxController) return console.error("Combobox controller not found")

      const chipValues = this.entityWrapperTargets.map((target) => { return target.querySelector(".entities_entity_id").value })

      let allOptions = comboboxController._allOptions
      let toBeHidden = allOptions.filter((option) => { return chipValues.includes(option.dataset.value) })

      toBeHidden.forEach((option) => {
        option.classList.add("hidden")
        option.dataset.filterableAs = ""
      })
    })
  }
}
