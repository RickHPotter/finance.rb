import { Controller } from "@hotwired/stimulus"

// WHERE CREDITS ARE DUE:
// https://codepen.io/kniaza/pen/xxOaZBL
//
// Connects to data-controller="dark-mode"
export default class extends Controller {
  static targets = ['checkbox']

  connect() {
    this.theme_check()
  }

  theme_check() {
    const systemTheme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
    const userTheme = localStorage.getItem('theme')

    if (userTheme === 'dark' || (!userTheme && systemTheme === 'dark')) {
      this.set_dark_theme()
      this.checkboxTarget.checked = true
    } else {
      this.set_light_theme()
      this.checkboxTarget.checked = false
    }
  }

  toggle() {
    const state = this.checkboxTarget.checked
    if (state) {
      this.set_dark_theme()
      localStorage.setItem('theme', 'dark')
    } else {
      document.querySelector('body').classList.remove('dark')
      localStorage.setItem('theme', 'light')
    }
  }

  set_dark_theme() {
    document.querySelector('body').classList.add('dark')
  }

  set_light_theme() {
    document.querySelector('body').classList.remove('dark')
  }
}
