import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["iconOptionContainer", "iconOption", "selectedIcon", "iconIndicator"]

  connect() {}

  toggle() {
    this.iconOptionContainerTarget.classList.toggle("hidden")
  }

  selectIcon({ target }) {
    const button = target.closest("button")
    const iconName = button.dataset.name

    this.selectedIconTarget.value = iconName
    const selectedIconButton = this.iconOptionTargets.find(e => e.dataset.name === iconName)
    const selectedIcon = selectedIconButton.querySelector("img")
    this.iconIndicatorTarget.src = selectedIcon.src

    this.iconOptionContainerTarget.classList.add("hidden")
  }
}
