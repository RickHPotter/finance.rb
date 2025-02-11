import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["table", "row", "category", "entity"]

  connect() {
    this.initialise()
  }

  initialise() {
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
}
