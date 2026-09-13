import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["label"]
  static values = {
    updateUrl: String,
    lightLabel: String,
    darkLabel: String
  }

  connect() {
    this.render()
  }

  toggle() {
    const isDark = document.documentElement.classList.contains("dark")
    const nextTheme = isDark ? "light" : "dark"

    // Optimistic UI update
    document.documentElement.classList.toggle("dark", !isDark)
    this.render()

    // Save to local storage for instant reload before server responds
    try {
      window.localStorage.setItem("finance.theme", nextTheme)
    } catch (_) {}

    if (this.updateUrlValue) {
      const token = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')

      fetch(this.updateUrlValue, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': token,
          'Accept': 'application/json'
        },
        body: JSON.stringify({ user_preference: { theme: nextTheme } })
      })
    }
  }

  render() {
    const dark = document.documentElement.classList.contains("dark")
    const label = dark ? this.darkLabel : this.lightLabel

    if (this.hasLabelTarget) {
      this.labelTarget.textContent = label
    } else {
      this.element.textContent = label
    }

    this.element.setAttribute("aria-pressed", dark.toString())
  }

  get lightLabel() {
    return this.hasLightLabelValue ? this.lightLabelValue : "Light"
  }

  get darkLabel() {
    return this.hasDarkLabelValue ? this.darkLabelValue : "Dark"
  }
}
