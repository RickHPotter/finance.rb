import { Controller } from "@hotwired/stimulus"

let installPromptEvent
const controllers = new Set()
const isStandaloneApp = window.matchMedia("(display-mode: standalone)").matches
const supportsInstallPrompt = "onbeforeinstallprompt" in window

const appAlreadyInstalled = () => window.APP_LOCALE === "en" ? "The app is already installed." : "A aplicação já está instalada."
const appAlreadyInstalledOrBrowserDoesNotSupport = () => window.APP_LOCALE === "en" ? "The app is already installed or the browser doesn’t support it." : "A aplicação já está instalada ou o navegador não suporta."
const thankYouForInstalling = () => window.APP_LOCALE === "en" ? "Thank you for installing 30/Fev!" : "Obrigado por instalar 30/Fev!"
const alreadyUsingTheApp = () => window.APP_LOCALE === "en" ? "Coll, you are using the standalone app." : "Massa! Você já está usando a versão app."

window.addEventListener("beforeinstallprompt", async (event) => {
  event.preventDefault()

  installPromptEvent = event
  controllers.forEach((controller) => {
    controller.initializeDisplay()
    if (!installPromptEvent) {
      controller.showMessage("notice", appAlreadyInstalled())
    }
  })
})

window.addEventListener("appinstalled", (event) => {
  controllers.forEach((controller) => {
    controller.showMessage("notice", thankYouForInstalling())
  })
})

export default class extends Controller {
  static targets = ["installButton", "infoButton", "dialog", "message"]

  connect() {}

  async install() {
    if (isStandaloneApp) {
      this.showMessage("notice", appAlreadyInstalled())
      this.hideInstallButton()
      return
    }

    if (!installPromptEvent) {
      this.showMessage("alert", appAlreadyInstalledOrBrowserDoesNotSupport())
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
      this.showMessage("notice", alreadyUsingTheApp)
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
