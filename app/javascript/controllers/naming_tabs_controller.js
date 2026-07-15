import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { current: String }

  connect() {
    if (this.hasCurrentValue && this.currentValue === "") return

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
      tab.setAttribute("aria-selected", active.toString())
      tab.tabIndex = active ? 0 : -1
      tab.classList.toggle("bg-sky-500", active)
      tab.classList.toggle("text-white", active)
      tab.classList.toggle("bg-gray-200", !active)
      tab.classList.toggle("text-gray-700", !active)
      tab.classList.toggle("dark:bg-slate-800", !active)
      tab.classList.toggle("dark:text-slate-200", !active)
    })

    this.panelTargets.forEach((panel) => {
      const active = panel.dataset.namingTabsName === name
      panel.setAttribute("aria-hidden", (!active).toString())
      panel.classList.toggle("hidden", !active)
      if (active) this.loadPanel(panel)
    })
  }

  loadPanel(panel) {
    const frame = panel.querySelector("turbo-frame[data-naming-tabs-lazy-src]")
    if (!frame || frame.getAttribute("src")) return

    frame.setAttribute("src", frame.dataset.namingTabsLazySrc)
  }
}
