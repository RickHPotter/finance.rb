import { Controller } from "@hotwired/stimulus"
import { automaticForeground, normalizeHex } from "../lib/category_colour_contrast.mjs"

export default class extends Controller {
  static targets = [
    "optionContainer", "option", "selectedValue", "indicator",
    "customInput", "hexField", "trigger"
  ]

  static values = { field: String }

  connect() {
    this.render(this.selectedValueTarget.value)
  }

  toggle() {
    const opening = this.optionContainerTarget.classList.contains("hidden")
    this.optionContainerTarget.classList.toggle("hidden", !opening)
    this.triggerTarget.setAttribute("aria-expanded", opening.toString())
  }

  close() {
    this.optionContainerTarget.classList.add("hidden")
    this.triggerTarget.setAttribute("aria-expanded", "false")
  }

  selectColour(event) {
    event.preventDefault()
    this.commit(event.currentTarget.dataset.value)
    this.close()
  }

  pickCustom(event) {
    this.commit(event.currentTarget.value)
  }

  hexChanged(event) {
    const value = event.currentTarget.value
    const normalized = normalizeHex(value)

    this.selectedValueTarget.value = value
    if (normalized) {
      this.customInputTarget.value = normalized
      this.render(normalized)
    } else {
      this.renderInvalid()
    }
    this.emitChange(value, normalized)
  }

  commit(value) {
    const normalized = normalizeHex(value)
    if (!normalized) {
      this.selectedValueTarget.value = value
      this.hexFieldTarget.value = value
      this.renderInvalid()
      this.emitChange(value, null)
      return
    }

    this.selectedValueTarget.value = normalized
    this.hexFieldTarget.value = normalized
    this.customInputTarget.value = normalized
    this.render(normalized)
    this.emitChange(normalized, normalized)
  }

  render(value) {
    const normalized = normalizeHex(value)
    if (!normalized) {
      this.renderInvalid()
      return
    }

    const foreground = automaticForeground(normalized)
    this.indicatorTarget.style.backgroundColor = normalized
    this.indicatorTarget.style.color = foreground
    this.indicatorTarget.dataset.text = foreground
    this.indicatorTarget.dataset.valid = "true"

    this.optionTargets.forEach(option => {
      option.setAttribute("aria-pressed", (normalizeHex(option.dataset.value) === normalized).toString())
    })
  }

  renderInvalid() {
    this.indicatorTarget.style.backgroundColor = "#e2e8f0"
    this.indicatorTarget.style.color = "#0f172a"
    this.indicatorTarget.dataset.text = ""
    this.indicatorTarget.dataset.valid = "false"
    this.optionTargets.forEach(option => option.setAttribute("aria-pressed", "false"))
  }

  emitChange(value, normalized) {
    this.dispatch("change", {
      detail: {
        field: this.fieldValue,
        value,
        normalized,
        valid: normalized !== null
      }
    })
  }
}
