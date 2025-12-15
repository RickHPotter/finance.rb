import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  async fetch(event) {
    event.preventDefault()
    
    const response = await fetch(this.urlValue, {
      headers: {
        Accept: "text/vnd.turbo-stream.html",
      },
    })
    const stream = await response.text()
    Turbo.renderStreamMessage(stream)
  }
}
