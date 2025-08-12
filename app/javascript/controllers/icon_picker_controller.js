import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["iconOptionContainer", "iconOption", "selectedIcon", "iconIndicator", "tabButton", "iconContainer"]

  connect() {}

  toggle() {
    this.iconOptionContainerTarget.classList.toggle("hidden")
  }

  selectIcon({ target }) {
    const button = target.closest("button")
    const iconName = button.dataset.name
    const tabName = button.parentElement.dataset.tab

    this.selectedIconTarget.value = `${tabName}/${iconName}`
    const selectedTab = this.element.querySelector("div[data-tab='" + tabName + "']")
    const selectedIconButton = selectedTab.querySelector("[data-name='" + iconName + "']")
    const selectedIcon = selectedIconButton.querySelector("img")
    this.iconIndicatorTarget.src = selectedIcon.src

    this.iconOptionContainerTarget.classList.add("hidden")
  }

  switchTab(event) {
    const selectedTab = event.currentTarget.dataset.tab

    this.tabButtonTargets.forEach(tab => {
      tab.dataset.active = tab.dataset.tab === selectedTab
    })

    this.iconContainerTargets.forEach(container => {
      container.classList.toggle("hidden", container.dataset.tab !== selectedTab)
    })
  }
}
