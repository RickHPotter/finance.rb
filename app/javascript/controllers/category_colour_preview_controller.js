import { Controller } from "@hotwired/stimulus"
import {
  MINIMUM_RATIO,
  assessContrast,
  automaticForeground,
  formatRatio,
  normalizeHex
} from "../lib/category_colour_contrast.mjs"

const SAFE_BACKGROUND = "#e2e8f0"
const SAFE_FOREGROUND = "#0f172a"
const STATUS_CLASSES = {
  invalid: ["text-amber-700", "dark:text-amber-300"],
  passing: ["text-emerald-700", "dark:text-emerald-300"],
  failing: ["text-red-700", "dark:text-red-300"]
}

export default class extends Controller {
  static targets = [
    "backgroundInput", "foregroundInput", "manualFields", "modeInput",
    "ratio", "status", "suggestion", "preview", "categoryNameInput"
  ]

  static values = {
    minimumRatio: { type: Number, default: MINIMUM_RATIO },
    passingLabel: String,
    failingLabel: String,
    invalidLabel: String,
    suggestionLabel: String,
    fallbackLabel: String
  }

  connect() {
    this.render()
  }

  colourChanged() {
    this.render()
  }

  modeChanged() {
    this.render()
  }

  nameChanged() {
    this.renderPreviewLabels()
  }

  render() {
    const manual = this.manualMode
    this.manualFieldsTarget.classList.toggle("hidden", !manual)
    this.manualFieldsTarget.setAttribute("aria-hidden", (!manual).toString())
    this.foregroundInputTarget.disabled = !manual

    const background = normalizeHex(this.backgroundInputTarget.value)
    const foreground = manual
      ? normalizeHex(this.foregroundInputTarget.value)
      : automaticForeground(background)
    const assessment = assessContrast(background, foreground, this.minimumRatioValue)

    this.renderStatus(assessment, background, manual)
    this.renderPreviews(assessment)
    this.renderPreviewLabels()
  }

  renderStatus(assessment, background, manual) {
    if (!assessment) {
      this.ratioTarget.textContent = "—"
      this.statusTarget.textContent = this.invalidLabelValue
      this.setStatusState("invalid")
      this.suggestionTarget.textContent = background
        ? `${this.suggestionLabelValue} ${automaticForeground(background)}`
        : ""
      return
    }

    this.ratioTarget.textContent = formatRatio(assessment.ratio)
    this.statusTarget.textContent = assessment.passing ? this.passingLabelValue : this.failingLabelValue
    this.setStatusState(assessment.passing ? "passing" : "failing")
    this.suggestionTarget.textContent = manual && !assessment.passing
      ? `${this.suggestionLabelValue} ${assessment.suggestedForeground}`
      : ""
  }

  setStatusState(state) {
    Object.values(STATUS_CLASSES).flat().forEach(className => this.statusTarget.classList.remove(className))
    this.statusTarget.classList.add(...STATUS_CLASSES[state])
    this.statusTarget.dataset.state = state
  }

  renderPreviews(assessment) {
    const background = assessment?.background || SAFE_BACKGROUND
    const foreground = assessment?.foreground || SAFE_FOREGROUND

    this.previewTargets.forEach(preview => {
      preview.style.backgroundColor = background
      preview.style.color = foreground
      preview.style.borderColor = foreground
      preview.style.opacity = ""
      preview.style.filter = ""
      preview.style.boxShadow = this.previewShadow(preview.dataset.previewState, foreground)
      preview.style.borderStyle = preview.dataset.previewState === "disabled" ? "dashed" : "solid"
      preview.dataset.contrastPassing = (assessment?.passing || false).toString()
    })
  }

  renderPreviewLabels() {
    const label = this.categoryNameInputTarget.value.trim() || this.fallbackLabelValue
    this.previewTargets.forEach(preview => {
      preview.textContent = label
    })
  }

  previewShadow(state, foreground) {
    switch (state) {
      case "hover":
        return "0 4px 6px rgba(15, 23, 42, 0.25)"
      case "focus":
        return "0 0 0 2px #ffffff, 0 0 0 4px #000000"
      case "selected":
        return `inset 0 0 0 2px ${foreground}`
      default:
        return ""
    }
  }

  get manualMode() {
    return this.modeInputTargets.find(input => input.checked)?.value === "manual"
  }
}
