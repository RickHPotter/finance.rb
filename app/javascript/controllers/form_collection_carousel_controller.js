import { Controller } from "@hotwired/stimulus"
import EmblaCarousel from "embla-carousel"

export default class extends Controller {
  static targets = ["viewport", "prevButton", "nextButton"]

  connect() {
    this.boundReinitialize = this.reinitialize.bind(this)
    this.boundUpdateButtons = this.updateButtons.bind(this)
    this.element.addEventListener("rails-nested-form:add", this.boundReinitialize)
    this.reinitialize()
  }

  disconnect() {
    this.element.removeEventListener("rails-nested-form:add", this.boundReinitialize)
    this.destroyCarousel()
  }

  scrollPrev() {
    if (!this.carousel) return

    this.carousel.scrollPrev()
    this.updateButtons()
  }

  scrollNext() {
    if (!this.carousel) return

    this.carousel.scrollNext()
    this.updateButtons()
  }

  reinitialize() {
    requestAnimationFrame(() => requestAnimationFrame(() => {
      this.destroyCarousel()
      this.carousel = EmblaCarousel(this.viewportTarget, {
        loop: false,
        align: "start",
        containScroll: "trimSnaps",
        dragFree: true
      })
      this.attachListeners()
      this.updateButtons()
      requestAnimationFrame(() => this.updateButtons())
    }))
  }

  destroyCarousel() {
    this.detachListeners()
    if (!this.carousel) return

    this.carousel.destroy()
    this.carousel = null
  }

  attachListeners() {
    if (!this.carousel || this.listenersAttached) return

    this.carousel.on("select", this.boundUpdateButtons)
    this.carousel.on("reInit", this.boundUpdateButtons)
    this.carousel.on("settle", this.boundUpdateButtons)
    this.listenersAttached = true
  }

  detachListeners() {
    if (!this.carousel) {
      this.listenersAttached = false
      return
    }
    if (!this.listenersAttached) return

    this.carousel.off("select", this.boundUpdateButtons)
    this.carousel.off("reInit", this.boundUpdateButtons)
    this.carousel.off("settle", this.boundUpdateButtons)
    this.listenersAttached = false
  }

  updateButtons() {
    if (!this.carousel) {
      this.prevButtonTarget.disabled = true
      this.nextButtonTarget.disabled = true
      return
    }

    this.prevButtonTarget.disabled = !this.carousel.canScrollPrev()
    this.nextButtonTarget.disabled = !this.carousel.canScrollNext()
  }
}
