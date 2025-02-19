import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["table", "row", "category", "entity"]

  connect() {
    this.initialise()
  }

  initialise() {
    document.addEventListener("dragover", (event) => {
      event.preventDefault()
    })

    document.addEventListener("drop", (event) => {
      const transactionId = event.dataTransfer.getData("text/plain")
      const monthBtn = event.target.closest("[data-month-year-selector-target='monthYear']")
      // TODO: implement dragging to another month, or maybe even to another card
      // implement also a toast with undo button and, obviously the undo functionality
    })
  }

  filter(event) {
    const searchTerm = event.target.value.toLowerCase();
    this.rowTargets.forEach(row => {
      row.style.display = row.innerText.toLowerCase().includes(searchTerm) ? "" : "none"
    })
  }

  filterCategory(event) {
    const searchTerm = event.target.value.toLowerCase();

    this.categoryTargets.forEach(categoryField => {
      const categoryIds = categoryField.dataset.id
      if (categoryIds.includes(searchTerm)) {
        categoryField.parentElement.style.display = ""
      } else {
        categoryField.parentElement.style.display = "none"
      }
    })
  }

  filterEntity(event) {
    const searchTerm = event.target.value.toLowerCase();

    this.entityTargets.forEach(entityField => {
      const entityIds = entityField.dataset.id
      if (entityIds.includes(searchTerm)) {
        entityField.parentElement.style.display = ""
      } else {
        entityField.parentElement.style.display = "none"
      }
    })
  }

  start(event) {
    event.dataTransfer.setData("text/plain", event.target.dataset.id)
    event.target.classList.add("opacity-50")
  }

  activate(event) {
    event.preventDefault()
  }

  drop(event) {
    event.preventDefault()
    event.target.classList.remove("opacity-50")
  }
}
