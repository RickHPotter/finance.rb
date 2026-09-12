import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "feedback"]

  async copy() {
    const value = this.sourceTarget.value

    try {
      await navigator.clipboard.writeText(value)
    } catch (_) {
      this.sourceTarget.select()
      document.execCommand("copy")
      this.sourceTarget.setSelectionRange(0, 0)
    }

    this.feedbackTarget.classList.remove("hidden")
  }
}
