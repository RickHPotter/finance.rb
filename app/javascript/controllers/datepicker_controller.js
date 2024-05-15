import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="datepicker"
export default class extends Controller {
  static targets = ["date"]

  updateDate() {
    const dateElement = this.dateTarget
    const epoch = dateElement.datepicker.getDate()
    const date = new Date(epoch)

    const { fieldId } = dateElement.dataset
    const target = document.getElementById(fieldId)
    target.value = date.toISOString().slice(0, 10)
  }
}
