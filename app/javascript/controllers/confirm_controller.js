import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    linkId: String,
    href: String,
    method: String,
    turboFrame: String,
    turboStream: String,
    turboAction: String
  }

  connect() {
    if (this.element.parentElement !== document.body) {
      document.body.appendChild(this.element)
    }

    this.link = document.getElementById(this.linkIdValue)
    if (!this.link) return

    if (this.boundConfirm) {
      this.link.removeEventListener("click", this.boundConfirm)
    }

    this.boundConfirm = this.confirm.bind(this)
    this.link.addEventListener("click", this.boundConfirm)
  }

  disconnect() {
    if (this.link && this.boundConfirm) {
      this.link.removeEventListener("click", this.boundConfirm)
    }
  }

  confirm(event) {
    event.preventDefault()
    event.stopPropagation()
  }

  proceed() {
    if (this.hasHrefValue && this.hasMethodValue) {
      this.submitTurboMethodLink(this.methodValue, this.hrefValue)
      return
    }

    if (!this.link) return

    const method = this.link.getAttribute("data-turbo-method")

    if (method) {
      this.submitTurboMethodLink(method, this.link.href)
      return
    }

    this.link.removeEventListener("click", this.boundConfirm)
    this.link.click()
    this.link.addEventListener("click", this.boundConfirm)
  }

  submitTurboMethodLink(method, href) {
    const form = document.createElement("form")
    form.method = "post"
    form.action = href
    form.hidden = true

    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content
    const csrfParam = document.querySelector("meta[name='csrf-param']")?.content || "authenticity_token"
    const turboFrame = this.hasTurboFrameValue ? this.turboFrameValue : this.link?.getAttribute("data-turbo-frame")

    if (turboFrame) form.setAttribute("data-turbo-frame", turboFrame)
    if (this.hasTurboStreamValue) {
      form.setAttribute("data-turbo-stream", this.turboStreamValue)
    } else if (this.link?.hasAttribute("data-turbo-stream")) {
      form.setAttribute("data-turbo-stream", this.link.getAttribute("data-turbo-stream"))
    }

    if (this.hasTurboActionValue) {
      form.setAttribute("data-turbo-action", this.turboActionValue)
    } else if (this.link?.hasAttribute("data-turbo-action")) {
      form.setAttribute("data-turbo-action", this.link.getAttribute("data-turbo-action"))
    }

    form.appendChild(this.hiddenInput("_method", method))
    form.appendChild(this.hiddenInput(csrfParam, csrfToken))

    document.body.appendChild(form)
    form.requestSubmit()
  }

  hiddenInput(name, value) {
    const input = document.createElement("input")
    input.type = "hidden"
    input.name = name
    input.value = value || ""
    return input
  }
}
