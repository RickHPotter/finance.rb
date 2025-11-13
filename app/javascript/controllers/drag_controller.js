import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["handle"]

  connect() {
    this.isDragging = false
    this.initialX = 0
    this.initialY = 0
    this.xOffset = 0
    this.yOffset = 0

    this.handleTarget.addEventListener("mousedown", this.dragStart.bind(this))
    document.addEventListener("mousemove", this.drag.bind(this))
    document.addEventListener("mouseup", this.dragEnd.bind(this))
  }

  disconnect() {
    this.handleTarget.removeEventListener("mousedown", this.dragStart.bind(this))
    document.removeEventListener("mousemove", this.drag.bind(this))
    document.removeEventListener("mouseup", this.dragEnd.bind(this))
  }

  dragStart(e) {
    this.initialX = e.clientX - this.xOffset
    this.initialY = e.clientY - this.yOffset

    if (e.target === this.handleTarget) {
      this.isDragging = true
    }
  }

  drag(e) {
    if (this.isDragging) {
      e.preventDefault()
      this.currentX = e.clientX - this.initialX
      this.currentY = e.clientY - this.initialY

      this.xOffset = this.currentX
      this.yOffset = this.currentY

      this.setTranslate(this.currentX, this.currentY, this.element)
    }
  }

  dragEnd(e) {
    this.initialX = this.currentX
    this.initialY = this.currentY

    this.isDragging = false
  }

  setTranslate(xPos, yPos, el) {
    el.style.transform = `translate3d(${xPos}px, ${yPos}px, 0)`
  }
}
