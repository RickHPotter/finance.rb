import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { updateUrl: String }

  toggle() {
    const isDark = document.documentElement.classList.contains("dark")
    const nextTheme = isDark ? "light" : "dark"

    // Optimistic UI update
    document.documentElement.classList.toggle("dark", !isDark)
    this.element.textContent = isDark ? "Dark" : "Light"

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
}
