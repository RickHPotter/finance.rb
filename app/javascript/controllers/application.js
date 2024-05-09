import { Application } from "@hotwired/stimulus"

const application = Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus = application

export { application }

document.body.onkeydown = (e) => {
  const key = e.keyCode

  const isInputFocused = ['INPUT', 'TEXTAREA'].includes(document.activeElement.tagName)
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

  up_down_keys[index] && window.scrollBy({ top: up_down_command[index], left: 0, behavior: 'smooth' })

  // SET THEME
  const theme_key = 84 // t
  key === theme_key && document.getElementById('theme_toggle').click()
}
