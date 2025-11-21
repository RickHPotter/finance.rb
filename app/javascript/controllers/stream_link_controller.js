import { Controller } from "@hotwired/stimulus"
import { FetchRequest } from "@hotwired/turbo"

export default class extends Controller {
  static values = { url: String }

  connect() {
    this.element.addEventListener("click", (event) => {
      event.preventDefault()
      this.fetchStream()
    })
  }

  async fetchStream() {
    const request = new FetchRequest("get", this.urlValue, { responseKind: "turbo-stream" })
    await request.perform()
  }
}
