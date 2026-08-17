import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  start() {
    const progressBar = Turbo.navigator.delegate.adapter.progressBar

    progressBar.setValue(0)
    progressBar.show()
  }
}
