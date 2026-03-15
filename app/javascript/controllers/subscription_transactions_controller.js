import { Controller } from "@hotwired/stimulus"
import { _removeMask } from "../utils/mask.js"

// Connects to data-controller="subscription-transactions"
export default class extends Controller {
  static values = { locale: String }
  static targets = [
    "template", "target", "typeInput", "intervalInput", "startMonthYearInput", "endMonthYearInput",
    "startDateInput", "endDateInput", "cashAccountInput", "cardInput", "cashAccountWrapper", "cardWrapper",
    "priceInput", "transactionPriceInput", "totalPriceInput", "totalPriceDisplay", "nextButton"
  ]

  connect() {
    this.modalElement = document.getElementById("subscriptionAddTransactionModal")
    this.editingRow = null
    this.boundCloseModal = this.closeModal.bind(this)
    this.modalElement?.querySelectorAll('[data-modal-hide="subscriptionAddTransactionModal"]').forEach((element) => {
      element.addEventListener("click", this.boundCloseModal)
    })
    this.sortRows()
    this.recalculatePrice()
    this.refreshNextButton()
  }

  disconnect() {
    this.modalElement?.querySelectorAll('[data-modal-hide="subscriptionAddTransactionModal"]').forEach((element) => {
      element.removeEventListener("click", this.boundCloseModal)
    })
  }

  openCustomModal(event) {
    event.preventDefault()
    this.editingRow = null
    this.configureModalMode()
    this.applyDefaultType()
    this.populateDefaults()
    this.showModal()
  }

  openNextModal(event) {
    event.preventDefault()

    const row = this.latestOverallRow()
    if (!row) return

    this.editingRow = null
    this.populateNextFromRow(row)
    this.showModal()
  }

  editRow(event) {
    event.preventDefault()
    this.editingRow = event.currentTarget.closest(".nested-form-wrapper")
    if (!this.editingRow) return

    const type = this.editingRow.dataset.transactionType
    const input = this.typeInputTargets.find((candidate) => candidate.value === type)
    if (input) input.checked = true

    this.configureModalMode()
    this.changeType()
    this.populateFromRow(this.editingRow)
    this.showModal()
  }

  changeType() {
    const card = this.selectedType === "card"
    this.cashAccountWrapperTarget.classList.toggle("hidden", card)
    this.cardWrapperTarget.classList.toggle("hidden", !card)
    this.cashAccountInputTarget.required = !card
    this.cashAccountInputTarget.disabled = card
    this.cardInputTarget.required = card
    this.cardInputTarget.disabled = !card

    if (!this.editingRow) this.populateDefaults()
  }

  syncDates() {
    const startMonth = this.startMonthYearInputTarget.value
    const endMonth = this.endMonthYearInputTarget.value
    const startDate = this.startDateInputTarget.value

    if (this.editingRow && startMonth) {
      this.intervalInputTarget.value = "1"
      this.endMonthYearInputTarget.value = startMonth
    } else if (startMonth && !endMonth) {
      this.endMonthYearInputTarget.value = startMonth
    }

    if (startMonth && endMonth && endMonth < startMonth) {
      this.endMonthYearInputTarget.value = startMonth
    }

    if (!startDate && startMonth) {
      this.startDateInputTarget.value = this.defaultStartDateFor(startMonth)
    }

    const dates = this.generatedRows().map(({ dateValue }) => dateValue)
    this.endDateInputTarget.value = dates.at(-1) || this.startDateInputTarget.value
  }

  saveModalRows(event) {
    event.preventDefault()
    if (!this.modalIsValid()) return

    const target = this.findTarget(this.selectedType)
    const template = this.findTemplate(this.selectedType)
    if (!target || !template) return

    if (this.editingRow) {
      this.fillRow(this.editingRow, this.startDateInputTarget.value, this.startMonthYearInputTarget.value)
    } else {
      this.generatedRows().forEach(({ dateValue, monthYearValue }) => {
        const wrapper = this.buildRow(template.innerHTML)
        this.fillRow(wrapper, dateValue, monthYearValue)
        target.append(wrapper)
      })
    }

    this.sortRows()
    this.recalculatePrice()
    this.refreshNextButton()
    this.closeModal()
  }

  closeModal(event) {
    event?.preventDefault()
    this.editingRow = null
    this.configureModalMode()
    this.hideModal()
  }

  closeOnBackdrop(event) {
    if (event.target !== this.modalElement) return

    this.closeModal(event)
  }

  ignoreBackdrop(event) {
    event.stopPropagation()
  }

  populateDefaults() {
    const latestOverallRow = this.latestOverallRow()
    const latestTypeRow = this.latestRowFor(this.selectedType)

    if (!latestOverallRow) {
      this.applyEmptyDefaults()
      return
    }

    const overallDateField = latestOverallRow.querySelector('input[name$="[date]"]')
    const typePriceField = latestTypeRow?.querySelector('input[name$="[price]"]')
    const typeAccountField = latestTypeRow?.querySelector('input[name$="[user_bank_account_id]"]')
    const typeCardField = latestTypeRow?.querySelector('input[name$="[user_card_id]"]')

    this.startDateInputTarget.value = this.bumpMonth(overallDateField?.value || this.today)
    this.startMonthYearInputTarget.value = this.startDateInputTarget.value.slice(0, 7)
    this.endMonthYearInputTarget.value = this.startMonthYearInputTarget.value
    this.priceInputTarget.value = typePriceField?.value || 0

    if (this.selectedType === "cash") {
      this.cashAccountInputTarget.value = typeAccountField?.value || ""
    } else {
      this.cardInputTarget.value = typeCardField?.value || ""
    }

    this.applyPriceMask()
    this.syncDates()
  }

  applyDefaultType() {
    const latestType = this.latestOverallType()
    const desiredType = latestType || "card"
    const input = this.typeInputTargets.find((candidate) => candidate.value === desiredType)
    if (input) input.checked = true
    this.changeType()
  }

  applyEmptyDefaults() {
    if (!this.typeInputTargets.some((input) => input.checked)) {
      const defaultInput = this.typeInputTargets.find((input) => input.value === "card")
      if (defaultInput) defaultInput.checked = true
    }

    this.startDateInputTarget.value = this.today
    this.startMonthYearInputTarget.value = this.today.slice(0, 7)
    this.endMonthYearInputTarget.value = this.startMonthYearInputTarget.value
    this.intervalInputTarget.value = "1"
    this.priceInputTarget.value = 0
    this.cashAccountInputTarget.value = ""
    this.cardInputTarget.value = ""
    this.applyPriceMask()
    this.syncDates()
  }

  generatedRows() {
    const interval = parseInt(this.intervalInputTarget.value || "1", 10)
    const startDateValue = this.startDateInputTarget.value || this.defaultStartDateFor(this.startMonthYearInputTarget.value)
    const startDate = new Date(`${startDateValue}T00:00:00`)
    const months = this.monthSeries(interval)

    return months.map((monthYearValue, index) => {
      const date = new Date(startDate)
      date.setMonth(date.getMonth() + (index * interval))
      return { dateValue: this.formatDate(date), monthYearValue }
    })
  }

  monthSeries(interval) {
    const start = this.startMonthYearInputTarget.value
    const ending = this.endMonthYearInputTarget.value
    if (!start || !ending) return [start]

    const [startYear, startMonth] = start.split("-").map(Number)
    const [endYear, endMonth] = ending.split("-").map(Number)

    const months = []
    const cursor = new Date(startYear, startMonth - 1, 1)
    const finish = new Date(endYear, endMonth - 1, 1)

    while (cursor <= finish) {
      months.push(this.formatMonth(cursor))
      cursor.setMonth(cursor.getMonth() + interval)
    }

    return months
  }

  buildRow(templateContent) {
    const html = templateContent.replace(/NEW_RECORD/g, `${Date.now()}${Math.floor(Math.random() * 1000)}`)
    const fragment = document.createRange().createContextualFragment(html)
    return fragment.firstElementChild
  }

  fillRow(wrapper, dateValue, monthYearValue) {
    const dateField = wrapper.querySelector('input[name$="[date]"]')
    const priceField = wrapper.querySelector('input[name$="[price]"]')
    const accountField = wrapper.querySelector('input[name$="[user_bank_account_id]"]')
    const cardField = wrapper.querySelector('input[name$="[user_card_id]"]')

    if (dateField) dateField.value = dateValue
    if (priceField) {
      priceField.value = this.unmaskedPriceValue
      priceField.setAttribute("value", this.unmaskedPriceValue)
    }

    if (this.selectedType === "cash" && accountField) accountField.value = this.cashAccountInputTarget.value
    if (this.selectedType === "card" && cardField) cardField.value = this.cardInputTarget.value

    this.refreshRowDisplay(wrapper, monthYearValue)
  }

  removeRow() {
    setTimeout(() => {
      this.recalculatePrice()
      this.sortRows()
      this.refreshNextButton()
    }, 0)
  }

  recalculatePrice() {
    if (!this.hasTotalPriceInputTarget) return

    const total = this.transactionPriceInputTargets.reduce((sum, input) => {
      if (input.closest(".hidden")) return sum

      const destroyInput = input.closest(".nested-form-wrapper")?.querySelector('input[name$="[_destroy]"]')
      if (destroyInput?.value === "1") return sum

      return sum + this.parseNumber(input.value)
    }, 0)

    this.totalPriceInputTarget.value = total
    if (this.hasTotalPriceDisplayTarget) this.totalPriceDisplayTarget.textContent = this.formatCurrency(total)
  }

  latestRowFor(type) {
    return this.activeRows(this.findTarget(type))
      .find((row) => row.dataset.transactionType === type)
  }

  latestOverallType() {
    return this.latestOverallRow()?.dataset.transactionType
  }

  latestOverallRow() {
    return this.activeRows(this.element).at(0)
  }

  refreshNextButton() {
    if (!this.hasNextButtonTarget) return

    this.nextButtonTarget.disabled = !this.latestOverallRow()
  }

  findTarget(type) {
    return this.targetTargets.find((target) => target.dataset.kind === type) || this.targetTargets[0]
  }

  findTemplate(type) {
    return this.templateTargets.find((template) => template.dataset.kind === type)
  }

  get selectedType() {
    return this.typeInputTargets.find((input) => input.checked)?.value || "card"
  }

  parseNumber(value) {
    const normalized = `${value || ""}`.replace(/[^0-9,-.]/g, "").replace(/\.(?=.*\.)/g, "").replace(",", ".")
    const parsed = parseFloat(normalized)
    return Number.isNaN(parsed) ? 0 : parsed
  }

  get today() {
    return new Date().toISOString().slice(0, 10)
  }

  bumpMonth(dateValue) {
    const date = new Date(`${dateValue}T00:00:00`)
    date.setMonth(date.getMonth() + 1)
    return this.formatDate(date)
  }

  bumpMonthYear(monthYearValue) {
    if (!monthYearValue) return this.today.slice(0, 7)

    const [year, month] = monthYearValue.split("-").map(Number)
    const date = new Date(year, month - 1, 1)
    date.setMonth(date.getMonth() + 1)
    return this.formatMonth(date)
  }

  defaultStartDateFor(monthYearValue) {
    if (!monthYearValue) return this.today

    const [year, month] = monthYearValue.split("-").map(Number)
    if (!year || !month) return this.today

    const date = this.selectedType === "card" ? new Date(year, month - 2, 1) : new Date(year, month - 1, 1)
    return this.formatDate(date)
  }

  formatDate(date) {
    const year = date.getFullYear()
    const month = `${date.getMonth() + 1}`.padStart(2, "0")
    const day = `${date.getDate()}`.padStart(2, "0")
    return `${year}-${month}-${day}`
  }

  formatMonth(date) {
    const year = date.getFullYear()
    const month = `${date.getMonth() + 1}`.padStart(2, "0")
    return `${year}-${month}`
  }

  activeRows(element) {
    return Array.from(element?.querySelectorAll('.nested-form-wrapper[data-transaction-type]') || [])
      .filter((row) => {
        if (row.classList.contains("hidden")) return false

        const destroyInput = row.querySelector('input[name$="[_destroy]"]')
        return destroyInput?.value !== "1"
      })
  }

  modalIsValid() {
    const fields = [
      this.intervalInputTarget,
      this.priceInputTarget,
      this.startMonthYearInputTarget,
      this.endMonthYearInputTarget,
      this.startDateInputTarget,
      this.selectedType === "cash" ? this.cashAccountInputTarget : this.cardInputTarget
    ]

    const invalidField = fields.find((field) => !field.checkValidity())
    if (invalidField) {
      invalidField.reportValidity()
      return false
    }

    return true
  }

  populateFromRow(row) {
    const dateField = row.querySelector('input[name$="[date]"]')
    const priceField = row.querySelector('input[name$="[price]"]')
    const accountField = row.querySelector('input[name$="[user_bank_account_id]"]')
    const cardField = row.querySelector('input[name$="[user_card_id]"]')
    const rowMonthYear = row.dataset.sortMonthYear

    this.startDateInputTarget.value = dateField?.value || this.today
    this.startMonthYearInputTarget.value = rowMonthYear || this.startDateInputTarget.value.slice(0, 7)
    this.endMonthYearInputTarget.value = this.startMonthYearInputTarget.value
    this.priceInputTarget.value = priceField?.value || 0
    this.cashAccountInputTarget.value = accountField?.value || ""
    this.cardInputTarget.value = cardField?.value || ""
    this.intervalInputTarget.value = "1"
    this.applyPriceMask()
    this.syncDates()
  }

  populateNextFromRow(row) {
    const type = row.dataset.transactionType || "card"
    const input = this.typeInputTargets.find((candidate) => candidate.value === type)
    if (input) input.checked = true

    this.configureModalMode()
    this.changeType()

    const dateField = row.querySelector('input[name$="[date]"]')
    const priceField = row.querySelector('input[name$="[price]"]')
    const accountField = row.querySelector('input[name$="[user_bank_account_id]"]')
    const cardField = row.querySelector('input[name$="[user_card_id]"]')
    const currentDate = dateField?.value || this.today
    const currentMonthYear = row.dataset.sortMonthYear || currentDate.slice(0, 7)
    const nextDate = this.bumpMonth(currentDate)
    const nextMonthYear = this.bumpMonthYear(currentMonthYear)

    this.startDateInputTarget.value = nextDate
    this.startMonthYearInputTarget.value = nextMonthYear
    this.endMonthYearInputTarget.value = nextMonthYear
    this.intervalInputTarget.value = "1"
    this.priceInputTarget.value = priceField?.value || 0
    this.cashAccountInputTarget.value = accountField?.value || ""
    this.cardInputTarget.value = cardField?.value || ""
    this.applyPriceMask()
    this.syncDates()
  }

  configureModalMode() {
    const editing = Boolean(this.editingRow)

    this.intervalInputTarget.value = editing ? "1" : (this.intervalInputTarget.value || "1")
    this.intervalInputTarget.disabled = editing
    this.endMonthYearInputTarget.disabled = editing
  }

  refreshRowDisplay(wrapper, monthYearValue = null) {
    const dateField = wrapper.querySelector('input[name$="[date]"]')
    const priceField = wrapper.querySelector('input[name$="[price]"]')
    const accountField = wrapper.querySelector('input[name$="[user_bank_account_id]"]')
    const cardField = wrapper.querySelector('input[name$="[user_card_id]"]')

    const dateDisplay = wrapper.querySelector('[data-role="date-display"]')
    const priceDisplay = wrapper.querySelector('[data-role="price-display"]')
    const accountDisplay = wrapper.querySelector('[data-role="account-display"]')
    const cardDisplay = wrapper.querySelector('[data-role="card-display"]')
    const refMonthYearDisplay = wrapper.querySelector('[data-role="ref-month-year-display"]')

    if (dateDisplay && dateField?.value) dateDisplay.textContent = this.humanDate(dateField.value)
    if (priceDisplay) priceDisplay.textContent = this.formatCurrency(this.parseNumber(priceField?.value))
    if (accountDisplay) accountDisplay.textContent = this.selectedText(this.cashAccountInputTarget, accountField?.value)
    if (cardDisplay) cardDisplay.textContent = this.selectedText(this.cardInputTarget, cardField?.value)
    if (refMonthYearDisplay) refMonthYearDisplay.textContent = this.localizedRefMonthYear(monthYearValue || dateField?.value?.slice(0, 7))

    wrapper.dataset.sortMonthYear = monthYearValue || dateField?.value?.slice(0, 7) || "0000-00"
    wrapper.dataset.sortDate = dateField?.value || "0000-00-00"
    wrapper.dataset.sortDescription = this.descriptionValue
  }

  humanDate(value) {
    const [year, month, day] = value.split("-").map(Number)
    return new Intl.DateTimeFormat(this.normalizedLocale, { dateStyle: "long" }).format(new Date(year, month - 1, day)).toUpperCase()
  }

  formatCurrency(value) {
    return new Intl.NumberFormat(this.normalizedLocale, { style: "currency", currency: "BRL" }).format((value || 0) / 100)
  }

  selectedText(select, value) {
    return Array.from(select.options).find((option) => option.value === value)?.text || "-"
  }

  localizedRefMonthYear(value) {
    if (!value) return "-"

    const [year, month] = value.split("-").map(Number)
    const shortMonth = new Intl.DateTimeFormat(this.normalizedLocale, { month: "short" }).format(new Date(year, month - 1, 1)).replace(".", "").toUpperCase()
    return `${shortMonth} <${String(year).slice(-2)}>`
  }

  sortRows() {
    const target = this.targetTargets[0]
    if (!target) return

    Array.from(target.querySelectorAll(".nested-form-wrapper"))
      .sort((left, right) => {
        const monthComparison = (right.dataset.sortMonthYear || "").localeCompare(left.dataset.sortMonthYear || "")
        if (monthComparison !== 0) return monthComparison

        const dateComparison = (right.dataset.sortDate || "").localeCompare(left.dataset.sortDate || "")
        if (dateComparison !== 0) return dateComparison

        return (right.dataset.sortDescription || "").localeCompare(left.dataset.sortDescription || "")
      })
      .forEach((row) => target.append(row))
  }

  showModal() {
    if (!this.modalElement) return

    this.modalElement.classList.remove("hidden")
    this.modalElement.classList.add("flex")
  }

  hideModal() {
    if (!this.modalElement) return

    this.modalElement.classList.add("hidden")
    this.modalElement.classList.remove("flex")
  }

  get descriptionValue() {
    return this.element.querySelector("#subscription_description")?.value?.toLowerCase() || ""
  }

  get unmaskedPriceValue() {
    return _removeMask(this.priceInputTarget.value || "0")
  }

  get normalizedLocale() {
    return this.hasLocaleValue ? this.localeValue : "en"
  }

  applyPriceMask() {
    const priceMaskElement = this.priceInputTarget.closest('[data-controller~="price-mask"]')
    if (!priceMaskElement) return

    const priceMaskController = this.application.getControllerForElementAndIdentifier(priceMaskElement, "price-mask")
    priceMaskController?.applyMask({ target: this.priceInputTarget })
  }
}
