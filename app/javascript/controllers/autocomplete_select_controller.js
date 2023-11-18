import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="autocomplete-select"
export default class extends Controller {
  static targets = ["list", "item", "selected", "input"]

  connect() {
    this.originalListHTML = this.listTarget.innerHTML
  }

  toggle() {
    console.log('test')
    if (this.listTarget.classList.contains("hidden")) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.listTarget.innerHTML = this.originalListHTML
    this.selectedTarget.focus()
    this.listTarget.classList.remove("hidden")
  }

  close() {
    this.listTarget.classList.add("hidden")
  }

  choose(e) {
    const selectItem = e.currentTarget
    this.selectItem(selectItem)
    this.close()
  }

  selectItem(selectItem) {
    const id = selectItem.dataset.id
    this.selectedTarget.value = selectItem.querySelector(`[data-js="label"]`).innerText
    this.inputTarget.value = id

    this.itemTargets.forEach((itemTarget) => {
      itemTarget.querySelector(`[data-js="title"]`).classList.remove("font-semibold")
      itemTarget.querySelector(`[data-js="check"]`).classList.add("hidden")
    })

    selectItem.querySelector(`[data-js="title"]`).classList.add("font-semibold")
    selectItem.querySelector(`[data-js="check"]`).classList.remove("hidden")

    this.selectedTarget.focus()
  }

  filterList() {
    this.open()

    const inputValue = this.selectedTarget.value.toLowerCase()
    this.itemTargets.forEach((itemTarget) => {
      const itemLabel = itemTarget.querySelector(`[data-js="label"]`).innerText.toLowerCase()
      if (!itemLabel.includes(inputValue)) {
        itemTarget.classList.add("hidden")
      } else {
        itemTarget.classList.remove("hidden")
      }
    })
  }

  onKeyDown(event) {
    if (event.key === "Tab" && !this.listTarget.classList.contains("hidden")) {
      event.preventDefault()
      const visibleItems = this.itemTargets.filter((itemTarget) => !itemTarget.classList.contains("hidden"))
      if (visibleItems.length > 0) {
        const topItem = visibleItems[0]
        this.selectItem(topItem)
      }
      this.close()
    }
  }
}
