import { Controller } from "@hotwired/stimulus"
import EmblaCarousel from "embla-carousel"

export default class extends Controller {
  static targets = ["carouselRoot", "viewport", "content", "item", "expandSlot", "reduceSlot", "prevSlot", "nextSlot", "prevButton", "nextButton"]

  connect() {
    this.expanded = false
    this.boundReinitializeCarousel = this.reinitializeCarousel.bind(this)
    this.boundUpdateButtons = this.updateButtons.bind(this)
    this.boundUpdateButtonsFromScroll = this.updateButtons.bind(this)
    this.element.addEventListener("rails-nested-form:add", this.boundReinitializeCarousel)
    this.element.addEventListener("installments:layout-changed", this.boundReinitializeCarousel)
    this.applyMode()
  }

  disconnect() {
    this.element.removeEventListener("rails-nested-form:add", this.boundReinitializeCarousel)
    this.element.removeEventListener("installments:layout-changed", this.boundReinitializeCarousel)
    this.viewportTarget.removeEventListener("scroll", this.boundUpdateButtonsFromScroll)
    this.destroyCarousel()
  }

  scrollPrev() {
    if (this.expanded) return

    if (this.isMobile) {
      this.viewportTarget.scrollBy({ top: -this.mobileStep(), behavior: "smooth" })
      requestAnimationFrame(() => this.updateButtons())
      return
    }

    if (!this.carousel) return

    this.carousel.scrollPrev()
    this.updateButtons()
  }

  scrollNext() {
    if (this.expanded) return

    if (this.isMobile) {
      this.viewportTarget.scrollBy({ top: this.mobileStep(), behavior: "smooth" })
      requestAnimationFrame(() => this.updateButtons())
      return
    }

    if (!this.carousel) return

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
    if (this.isMobile) {
      this.destroyCarousel()
      this.viewportTarget.removeEventListener("scroll", this.boundUpdateButtonsFromScroll)
      this.viewportTarget.addEventListener("scroll", this.boundUpdateButtonsFromScroll)
      this.applyMobileViewportHeight()
      this.updateButtons()
      requestAnimationFrame(() => this.updateButtons())
      return
    }

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
    this.contentTarget.classList.toggle("sm:-ml-3", this.expanded)
    this.viewportTarget.style.overflow = this.expanded ? "visible" : ""
    this.viewportTarget.style.maxHeight = this.expanded ? "none" : ""
    this.contentTarget.style.transform = ""
    this.contentTarget.classList.toggle("flex-col", this.isMobile && !this.expanded)
    this.contentTarget.classList.toggle("sm:flex-row", !this.expanded)
    this.contentTarget.classList.toggle("sm:-ml-3", !this.expanded && !this.isMobile)

    this.itemTargets.forEach((item) => {
      item.classList.toggle("!basis-full", this.expanded)
      item.classList.toggle("sm:!basis-1/2", this.expanded)
      item.classList.toggle("md:!basis-1/3", this.expanded)
      item.classList.toggle("lg:!basis-1/4", this.expanded)
      item.classList.toggle("xl:!basis-1/5", this.expanded)
    })

    this.reduceSlotTarget.classList.toggle("hidden", !this.expanded)
    this.expandSlotTarget.classList.toggle("hidden", this.expanded)
    this.prevSlotTarget.classList.toggle("row-span-2", !this.expanded)
    this.nextSlotTarget.classList.toggle("row-span-2", this.expanded)
    this.prevSlotTarget.classList.toggle("col-span-2", this.isMobile && !this.expanded)
    this.nextSlotTarget.classList.toggle("col-span-2", this.isMobile && this.expanded)
    this.prevButtonTarget.disabled = this.expanded
    this.nextButtonTarget.disabled = this.expanded

    if (this.expanded) {
      this.destroyCarousel()
    } else {
      this.reinitializeCarousel()
    }
  }

  get isMobile() {
    return window.matchMedia("(max-width: 639px)").matches
  }

  destroyCarousel() {
    this.detachCarouselListeners()
    this.viewportTarget.removeEventListener("scroll", this.boundUpdateButtonsFromScroll)

    if (!this.carousel) return

    this.carousel.destroy()
    this.carousel = null
  }

  updateButtons() {
    if (this.expanded) {
      this.prevButtonTarget.disabled = true
      this.nextButtonTarget.disabled = true
      return
    }

    if (this.isMobile) {
      const maxScrollTop = Math.max(this.viewportTarget.scrollHeight - this.viewportTarget.clientHeight, 0)

      this.prevButtonTarget.disabled = this.viewportTarget.scrollTop <= 1
      this.nextButtonTarget.disabled = this.viewportTarget.scrollTop >= maxScrollTop - 1
      return
    }

    if (!this.carousel) {
      this.prevButtonTarget.disabled = true
      this.nextButtonTarget.disabled = true
      return
    }

    this.prevButtonTarget.disabled = !this.carousel.canScrollPrev()
    this.nextButtonTarget.disabled = !this.carousel.canScrollNext()
  }

  mobileStep() {
    const firstItem = this.itemTargets[0]

    if (!firstItem) return this.viewportTarget.clientHeight

    const styles = window.getComputedStyle(firstItem)
    return firstItem.getBoundingClientRect().height + parseFloat(styles.marginTop || 0) + parseFloat(styles.marginBottom || 0)
  }

  applyMobileViewportHeight() {
    if (!this.isMobile || this.expanded) {
      this.viewportTarget.style.maxHeight = this.expanded ? "none" : ""
      return
    }

    const step = this.mobileStep()
    if (!step) return

    this.viewportTarget.style.maxHeight = `${step * 2}px`
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
