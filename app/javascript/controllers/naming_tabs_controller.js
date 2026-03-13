import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { current: String }

  connect() {
    const initial = this.currentValue || this.tabTargets[0]?.dataset.namingTabsName
    if (initial) this.show(initial)
  }

  select(event) {
    event.preventDefault()
    this.show(event.currentTarget.dataset.namingTabsName)
  }

  show(name) {
    this.currentValue = name

    this.tabTargets.forEach((tab) => {
      const active = tab.dataset.namingTabsName === name
      tab.classList.toggle("bg-sky-500", active)
      tab.classList.toggle("text-white", active)
      tab.classList.toggle("bg-gray-200", !active)
      tab.classList.toggle("text-gray-700", !active)
    })

    this.panelTargets.forEach((panel) => {
      panel.classList.toggle("hidden", panel.dataset.namingTabsName !== name)
    })
  }
}
