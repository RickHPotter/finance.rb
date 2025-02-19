import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "colourOptionContainer", "colourOption", "selectedColour", "colourIndicator"]

  connect() {}

  toggle() {
    this.colourOptionContainerTarget.classList.toggle("hidden")
  }

  selectColour({ target }) {
    const name = target.dataset.name
    const bg = target.dataset.bg

    this.selectedColourTarget.value = name
    this.colourIndicatorTarget.className = `w-6 h-6 rounded-full border border-slate-200 ${bg}`

    this.colourOptionContainerTarget.classList.add("hidden")
  }
}
