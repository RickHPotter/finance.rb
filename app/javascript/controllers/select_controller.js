import { Controller } from "@hotwired/stimulus"
import TomSelect from "tom-select"

export default class extends Controller {
  connect() {
    this.initializeTomSelect()
  }

  initializeTomSelect() {
    const tom = new TomSelect(this.element, {
      plugins: {
        remove_button: { title: "Remove this item" },
        clear_button: { title: "Remove all selected options" },
      },
      persist: false,
      allowEmptyOption: true,
      placeholder: this.element.dataset.placeholder
    })

    tom.on("item_add", () => {
      tom.setTextboxValue("")
      tom.refreshOptions(false)
    })

    if (!this.element.querySelector(".clear-button")) { return }

    this.element.querySelector(".clear-button").addEventListener("click", () => {
      this.element.querySelector("select").dispatchEvent(new Event("change"))
    })
  }
}
