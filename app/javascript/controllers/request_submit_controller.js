import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { formId: String }

  submit() {
    this.form?.requestSubmit()
  }

  get form() {
    if (this.hasFormIdValue) {
      return document.getElementById(this.formIdValue)
    }

    return this.element.form
  }
}
