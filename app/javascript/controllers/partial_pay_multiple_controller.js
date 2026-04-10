import { Controller } from "@hotwired/stimulus"
import { _applyMask, _removeMask } from "../utils/mask.js"

export default class extends Controller {
  static targets = [
    "idsInput",
    "selectionInput",
    "selectedTotal",
    "allowedRange",
    "amountInput",
    "installmentSelect",
    "message",
    "submitButton"
  ]

  static values = { locale: String }

  connect() {
    this.selection = []
    this.sync()
  }

  loadSelection(selection) {
    this.selection = Array.isArray(selection) ? selection : []
    this.selectionInputTarget.value = JSON.stringify(this.selection)

    const state = this.currentState()
    const defaultAmount = state.validRange ? state.minAllowed : 0
    this.amountInputTarget.value = _applyMask(defaultAmount.toString())
    this.sync()
  }

  sync() {
    const state = this.currentState()
    this.updateSummary(state)
    this.updateAmountBounds(state)
    this.updateInstallmentOptions(state)
    this.updateValidity(state)
  }

  currentState() {
    const selection = this.selectionFromInput()
    const signedPrices = selection.map((item) => parseInt(item.priceCents || "0", 10))
    const signs = signedPrices.map((price) => Math.sign(price)).filter((sign) => sign !== 0)
    const mixedSigns = new Set(signs).size > 1
    const totalAbs = selection.reduce((sum, item) => sum + (parseInt(item.priceAbsCents || "0", 10) || 0), 0)
    const largestAbs = selection.reduce((max, item) => Math.max(max, parseInt(item.priceAbsCents || "0", 10) || 0), 0)
    const minAllowed = totalAbs - largestAbs + 1
    const maxAllowed = totalAbs - 1
    const amount = Math.abs(parseInt(_removeMask(this.amountInputTarget?.value || "0"), 10) || 0)
    const validRange = selection.length > 0 && !mixedSigns && minAllowed <= maxAllowed
    const remainder = Math.max(totalAbs - amount, 0)
    const eligibleInstallments = validRange
      ? selection.filter((item) => (parseInt(item.priceAbsCents || "0", 10) || 0) > remainder)
      : []

    return {
      selection,
      totalAbs,
      mixedSigns,
      minAllowed,
      maxAllowed,
      amount,
      validRange,
      eligibleInstallments
    }
  }

  selectionFromInput() {
    if (!this.hasSelectionInputTarget || this.selectionInputTarget.value.trim() === "") return this.selection

    try {
      return JSON.parse(this.selectionInputTarget.value)
    } catch (_error) {
      return []
    }
  }

  updateSummary(state) {
    if (this.hasSelectedTotalTarget) {
      this.selectedTotalTarget.textContent = this.formatCurrency(state.totalAbs)
    }

    if (!this.hasAllowedRangeTarget) return

    if (!state.validRange) {
      this.allowedRangeTarget.textContent = `${this.formatCurrency(0)} - ${this.formatCurrency(0)}`
      return
    }

    this.allowedRangeTarget.textContent = `${this.formatCurrency(state.minAllowed)} - ${this.formatCurrency(state.maxAllowed)}`
  }

  updateAmountBounds(state) {
    if (!this.hasAmountInputTarget) return

    this.amountInputTarget.dataset.min = state.validRange ? state.minAllowed : ""
    this.amountInputTarget.dataset.max = state.validRange ? state.maxAllowed : ""
  }

  updateInstallmentOptions(state) {
    if (!this.hasInstallmentSelectTarget) return

    const currentValue = this.installmentSelectTarget.value
    const currentStillEligible = state.eligibleInstallments.some((item) => item.id.toString() === currentValue)

    this.installmentSelectTarget.innerHTML = ""

    const blankOption = document.createElement("option")
    blankOption.value = ""
    blankOption.textContent = this.translate("actions.select")
    this.installmentSelectTarget.append(blankOption)

    state.eligibleInstallments.forEach((item) => {
      const option = document.createElement("option")
      option.value = item.id
      option.textContent = item.label
      this.installmentSelectTarget.append(option)
    })

    this.installmentSelectTarget.value = currentStillEligible ? currentValue : ""
  }

  updateValidity(state) {
    const message = this.validationMessage(state)
    const amountValid = state.validRange && state.amount >= state.minAllowed && state.amount <= state.maxAllowed
    const selectionValid = amountValid && this.installmentSelectTarget.value !== ""
    const valid = message.length === 0 && selectionValid

    this.amountInputTarget.setCustomValidity(amountValid ? "" : message)
    this.installmentSelectTarget.setCustomValidity(selectionValid ? "" : message)

    if (this.hasMessageTarget) this.messageTarget.textContent = message
    if (this.hasSubmitButtonTarget) this.submitButtonTarget.disabled = !valid
  }

  validationMessage(state) {
    if (state.selection.length === 0) return this.translate("bulk_actions.empty_selection")
    if (state.mixedSigns) return this.translate("bulk_actions.partial_pay.mixed_signs")
    if (!state.validRange) return this.translate("bulk_actions.partial_pay.unavailable")

    if (state.amount < state.minAllowed || state.amount > state.maxAllowed) {
      return this.translate("bulk_actions.partial_pay.invalid_amount")
    }

    if (state.eligibleInstallments.length === 0 || this.installmentSelectTarget.value === "") {
      return this.translate("bulk_actions.partial_pay.invalid_selection")
    }

    return ""
  }

  translate(key) {
    const translations = (this.localeValue || document.documentElement.lang || "en") === "pt-BR"
      ? {
          "actions.select": "Selecione um",
          "bulk_actions.empty_selection": "Selecione pelo menos uma transação.",
          "bulk_actions.partial_pay.mixed_signs": "O pagamento parcial exige transações selecionadas com o mesmo sinal.",
          "bulk_actions.partial_pay.unavailable": "Pagamento parcial não está disponível para esta seleção.",
          "bulk_actions.partial_pay.invalid_amount": "Escolha um valor que quite totalmente todas as transações selecionadas, exceto uma.",
          "bulk_actions.partial_pay.invalid_selection": "Escolha qual transação permanecerá parcialmente paga."
        }
      : {
          "actions.select": "Select one",
          "bulk_actions.empty_selection": "Select at least one transaction.",
          "bulk_actions.partial_pay.mixed_signs": "Partial pay requires selected transactions with the same sign.",
          "bulk_actions.partial_pay.unavailable": "Partial pay is not available for this selection.",
          "bulk_actions.partial_pay.invalid_amount": "Choose an amount that fully pays all selected transactions except one.",
          "bulk_actions.partial_pay.invalid_selection": "Choose which transaction will remain partially paid."
        }

    return translations[key] || ""
  }

  formatCurrency(cents) {
    return new Intl.NumberFormat(this.localeValue || document.documentElement.lang || "en", {
      style: "currency",
      currency: "BRL"
    }).format((cents || 0) / 100)
  }
}
