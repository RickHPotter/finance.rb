import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "finance.theme"

export default class extends Controller {
  connect() {
    this.sync()
  }

  toggle() {
    const nextTheme = this.currentTheme() === "dark" ? "light" : "dark"
    this.apply(nextTheme)

    try {
      window.localStorage.setItem(STORAGE_KEY, nextTheme)
    } catch (_) {}
  }

  sync() {
    this.apply(this.currentTheme())
  }

  currentTheme() {
    return document.documentElement.classList.contains("dark") ? "dark" : "light"
  }

  apply(theme) {
    const dark = theme === "dark"

    document.documentElement.classList.toggle("dark", dark)
    this.element.setAttribute("aria-pressed", String(dark))
    this.element.setAttribute("title", dark ? "Switch to light theme" : "Switch to dark theme")
    this.element.textContent = dark ? "Dark" : "Light"
  }
}
