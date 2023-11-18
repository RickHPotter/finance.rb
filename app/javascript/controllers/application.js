import { Application } from "@hotwired/stimulus"

const application = Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus = application

export { application }

document.body.onkeydown = (e) => {
  const key = e.keyCode
  const keys = [74, 75]
  const top = [150, -150]
  const index = keys.indexOf(key)

  keys[index] && window.scrollBy({ top: top[index], left: 0, behavior: 'smooth' })
}
