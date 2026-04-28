import { Controller } from "@hotwired/stimulus"
import EmblaCarousel from "embla-carousel"

export default class extends Controller {
  static targets = ["carouselRoot", "viewport", "content", "item", "expandSlot", "reduceSlot", "prevSlot", "nextSlot", "prevButton", "nextButton"]

  connect() {
    this.expanded = false
    this.boundReinitializeCarousel = this.reinitializeCarousel.bind(this)
    this.boundUpdateButtons = this.updateButtons.bind(this)
    this.element.addEventListener("rails-nested-form:add", this.boundReinitializeCarousel)
    this.element.addEventListener("installments:layout-changed", this.boundReinitializeCarousel)
    this.applyMode()
  }

  disconnect() {
    this.element.removeEventListener("rails-nested-form:add", this.boundReinitializeCarousel)
    this.element.removeEventListener("installments:layout-changed", this.boundReinitializeCarousel)
    this.destroyCarousel()
  }

  scrollPrev() {
    if (this.expanded || !this.carousel) return

    this.carousel.scrollPrev()
    this.updateButtons()
  }

  scrollNext() {
    if (this.expanded || !this.carousel) return

    this.carousel.scrollNext()
    this.updateButtons()
  }

  toggle() {
    this.expanded = !this.expanded
    this.applyMode()
  }

  reinitializeCarousel() {
    if (this.expanded) return

    requestAnimationFrame(() => requestAnimationFrame(() => {
      this.destroyCarousel()
      this.carousel = EmblaCarousel(this.viewportTarget, {
        loop: false,
        align: "start",
        containScroll: "trimSnaps"
      })
      this.attachCarouselListeners()
      this.updateButtons()
      requestAnimationFrame(() => this.updateButtons())
    }))
  }

  applyMode() {
    this.viewportTarget.classList.toggle("overflow-visible", this.expanded)
    this.viewportTarget.classList.toggle("overflow-hidden", !this.expanded)
    this.contentTarget.classList.toggle("flex-wrap", this.expanded)
    this.contentTarget.classList.toggle("gap-y-3", this.expanded)
    this.contentTarget.classList.toggle("md:-ml-3", this.expanded)
    this.viewportTarget.style.overflow = this.expanded ? "visible" : ""
    this.contentTarget.style.transform = ""

    this.itemTargets.forEach((item) => {
      item.classList.toggle("!basis-full", this.expanded)
      item.classList.toggle("md:!basis-1/2", this.expanded)
      item.classList.toggle("lg:!basis-1/3", this.expanded)
      item.classList.toggle("xl:!basis-1/4", this.expanded)
    })

    this.reduceSlotTarget.classList.toggle("hidden", !this.expanded)
    this.expandSlotTarget.classList.toggle("hidden", this.expanded)
    this.prevSlotTarget.classList.toggle("row-span-2", !this.expanded)
    this.nextSlotTarget.classList.toggle("row-span-2", this.expanded)
    this.prevButtonTarget.disabled = this.expanded
    this.nextButtonTarget.disabled = this.expanded

    if (this.expanded) {
      this.destroyCarousel()
    } else {
      this.reinitializeCarousel()
    }
  }

  destroyCarousel() {
    this.detachCarouselListeners()

    if (!this.carousel) return

    this.carousel.destroy()
    this.carousel = null
  }

  updateButtons() {
    if (this.expanded || !this.carousel) {
      this.prevButtonTarget.disabled = true
      this.nextButtonTarget.disabled = true
      return
    }

    this.prevButtonTarget.disabled = !this.carousel.canScrollPrev()
    this.nextButtonTarget.disabled = !this.carousel.canScrollNext()
  }

  attachCarouselListeners() {
    if (!this.carousel) return
    if (this.carouselListenersAttached) return

    this.carousel.on("select", this.boundUpdateButtons)
    this.carousel.on("reInit", this.boundUpdateButtons)
    this.carousel.on("settle", this.boundUpdateButtons)
    this.carouselListenersAttached = true
  }

  detachCarouselListeners() {
    if (!this.carousel) {
      this.carouselListenersAttached = false
      return
    }

    if (!this.carouselListenersAttached) return

    this.carousel.off("select", this.boundUpdateButtons)
    this.carousel.off("reInit", this.boundUpdateButtons)
    this.carousel.off("settle", this.boundUpdateButtons)
    this.carouselListenersAttached = false
  }
}
