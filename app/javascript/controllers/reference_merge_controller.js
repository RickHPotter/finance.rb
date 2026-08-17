import { Controller } from "@hotwired/stimulus"
import { isForwardAdjacentMonth } from "../lib/reference_merge_mode.mjs"

export default class extends Controller {
  static targets = [ "source", "target", "reallocate", "reallocateLabel" ]

  connect() {
    this.syncModeAvailability()
  }

  syncModeAvailability() {
    const available = isForwardAdjacentMonth(this.sourceTarget.value, this.targetTarget.value)

    this.reallocateTarget.disabled = !available
    this.reallocateLabelTarget.classList.toggle("cursor-not-allowed", !available)
    this.reallocateLabelTarget.classList.toggle("opacity-50", !available)
    this.reallocateLabelTarget.setAttribute("aria-disabled", String(!available))

    if (!available) this.reallocateTarget.checked = false
  }
}
