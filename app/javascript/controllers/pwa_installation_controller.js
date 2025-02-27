import { Controller } from "@hotwired/stimulus"

let installPromptEvent
const controllers = new Set()
const isStandaloneApp = window.matchMedia("(display-mode: standalone)").matches
const supportsInstallPrompt = "onbeforeinstallprompt" in window

// Listen for the `beforeinstallprompt` event to customize the install prompt UX with our own button.
// Note that this event is currently only implemented in Chromium based browsers.
// @see https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/How_to/Trigger_install_prompt
window.addEventListener("beforeinstallprompt", async (event) => {
  event.preventDefault()

  installPromptEvent = event
  controllers.forEach((controller) => {
    controller.initializeDisplay()
    if (!installPromptEvent) {
      controller.showMessage("notice", "The app is already installed!")
    }
  })
})

window.addEventListener("appinstalled", (event) => {
  controllers.forEach((controller) => {
    controller.showMessage("notice", "Thank you for installing Joy of Rails!")
  })
})

export default class extends Controller {
  static targets = ["installButton", "infoButton", "dialog", "message"]

  connect() {}

  async install() {
    if (isStandaloneApp) {
      this.showMessage("notice", "The app is already installed.")
      this.hideInstallButton()
      return
    }

    if (!installPromptEvent) {
      this.showMessage("alert", "The app is already installed or the browser doesn’t support it.")
      this.hideInstallButton()
      return
    }

    const result = await installPromptEvent.prompt()
    installPromptEvent = null
    this.installButtonTarget.disabled = true
  }

  initializeDisplay() {
    this.removeMessage()

    if (isStandaloneApp) {
      this.hideInfoButton()
      this.showInstallButton({ disabled: true })
      this.showMessage("notice", "Cool, you are using the standalone app!")
    } else if (supportsInstallPrompt) {
      this.showInstallButton()
      this.hideInfoButton()
      if (!installPromptEvent) {
        return
      }
    } else {
      this.showInfoButton()
      this.hideInstallButton()
    }
  }

  showInstallButton({ disabled = false } = {}) {
    this.installButtonTarget.classList.remove("hidden")
    this.installButtonTarget.disabled = disabled || !installPromptEvent
  }

  hideInstallButton() {
    this.installButtonTarget.classList.add("hidden")
  }

  showInfoButton() {
    this.infoButtonTarget.classList.remove("hidden")
  }

  hideInfoButton() {
    this.infoButtonTarget.classList.add("hidden")
  }

  openDialog() {
    this.dialogTarget.showModal()
  }

  closeDialog(e) {
    e.preventDefault()
    this.dialogTarget.close()
  }

  clickOutside(e) {
    if (e.target === this.dialogTarget) {
      this.closeDialog(e)
    }
  }

  showMessage(type, message) {
    const frame = document.querySelector("turbo-frame#notification")
    frame.src = `pages/notification?${type}=${message}`
  }

  removeMessage() {
    const frame = document.querySelector("turbo-frame#notification")
    frame.innerHTML = ""
  }
}
