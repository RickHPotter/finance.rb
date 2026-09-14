import { Controller } from "@hotwired/stimulus"
import { mergeModeAvailability } from "../lib/reference_merge_mode.mjs"

export default class extends Controller {
  static targets = [ "source", "target", "reallocate", "reallocateLabel" ]

  connect() {
    this.updateModeAvailability({ preserveSelection: true })
  }

  syncModeAvailability() {
    this.updateModeAvailability()
  }

  updateModeAvailability({ preserveSelection = false } = {}) {
    const { available, clearSelection } = mergeModeAvailability(this.sourceTarget.value, this.targetTarget.value, { preserveSelection })

    this.reallocateTarget.disabled = !available
    this.reallocateLabelTarget.classList.toggle("cursor-not-allowed", !available)
    this.reallocateLabelTarget.classList.toggle("opacity-50", !available)
    this.reallocateLabelTarget.setAttribute("aria-disabled", String(!available))

    if (clearSelection) this.reallocateTarget.checked = false
  }
}
