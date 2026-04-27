import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  elevate() {
    this.row?.classList.add("exchange-sheet-active")
  }

  lower() {
    this.row?.classList.remove("exchange-sheet-active")
  }

  disconnect() {
    this.lower()
  }

  get row() {
    return this.element.closest("[data-datatable-target='row']")
  }
}
