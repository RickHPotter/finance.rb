import { Application } from "@hotwired/stimulus"

const application = Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus = application

import HwComboboxController from "@josefarias/hotwire_combobox"
application.register("hw-combobox", HwComboboxController)

export { application }

document.addEventListener("click", (event) => {
  const link = event.target.closest("a")

  if (
    link &&
    (event.ctrlKey || event.metaKey) &&
    link.href.includes(".turbo_stream")
  ) {
    event.preventDefault()
    link.click()
  }
})

document.addEventListener("DOMContentLoaded", () => {
  const validStandalonePaths = ["/", "/sidekiq", "/up"]
  const fullPath = window.location.pathname + window.location.search + window.location.hash

  if (!validStandalonePaths.includes(window.location.pathname)) {
    Turbo.visit("/")

    document.addEventListener("turbo:load", () => {
      console.info("you have been turbo hijacked")
      const centerFrame = document.getElementById("center_container")

      if (centerFrame) {
        const url = new URL(fullPath, window.location.origin)
        if (!url.searchParams.has("format")) {
          url.searchParams.set("format", "turbo_stream")
        }

        centerFrame.src = url.pathname + url.search + url.hash
      }
    })
  }
})

document.body.onkeydown = (e) => {
  const key = e.keyCode

  const isInputFocused = ["INPUT", "TEXTAREA"].includes(document.activeElement.tagName)
  if (isInputFocused) {
    if (key === 27) { // ESC
      document.activeElement.blur()
    }

    return
  }

  // NEOVIM
  const up_down_keys = [74, 75] // j, k
  const up_down_command = [150, -150]
  const index = up_down_keys.indexOf(key)

  up_down_keys[index] && window.scrollBy({ top: up_down_command[index], left: 0, behavior: "smooth" })

  // SET THEME
  const theme_key = 84 // t
  key === theme_key && document.getElementById("theme_toggle").click()
}
