import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list", "item", "badge"]

  connect() {
    this.updateBadges()
  }

  moveUp(event) {
    event.preventDefault()
    const item = event.currentTarget.closest("[data-baby-name-sort-target='item']")
    const prev = item.previousElementSibling
    if (prev) {
      this.listTarget.insertBefore(item, prev)
      this.updateBadges()
    }
  }

  moveDown(event) {
    event.preventDefault()
    const item = event.currentTarget.closest("[data-baby-name-sort-target='item']")
    const next = item.nextElementSibling
    if (next) {
      this.listTarget.insertBefore(next, item)
      this.updateBadges()
    }
  }

  updateBadges() {
    this.badgeTargets.forEach((badge, index) => {
      badge.textContent = `#${index + 1}`
    })
  }

  dragStart(event) {
    this.draggedItem = event.currentTarget.closest("[data-baby-name-sort-target='item']")
    this.draggedItem.classList.add("opacity-50", "scale-[0.98]")
    event.dataTransfer.effectAllowed = "move"
  }

  dragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
    const targetItem = event.currentTarget.closest("[data-baby-name-sort-target='item']")
    if (targetItem && targetItem !== this.draggedItem) {
      const rect = targetItem.getBoundingClientRect()
      const midY = rect.top + rect.height / 2
      if (event.clientY < midY) {
        this.listTarget.insertBefore(this.draggedItem, targetItem)
      } else {
        this.listTarget.insertBefore(this.draggedItem, targetItem.nextElementSibling)
      }
      this.updateBadges()
    }
  }

  dragEnd() {
    if (this.draggedItem) {
      this.draggedItem.classList.remove("opacity-50", "scale-[0.98]")
      this.draggedItem = null
    }
    this.updateBadges()
  }
}
