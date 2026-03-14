import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["top", "bottom"]

  connect() {
    this.lastScrollY = window.scrollY
    this.hideTimer = null
    this.onScroll = this.onScroll.bind(this)

    this.hideButtons()
    window.addEventListener("scroll", this.onScroll, { passive: true })
    document.addEventListener("scroll", this.onScroll, { passive: true, capture: true })
  }

  disconnect() {
    window.removeEventListener("scroll", this.onScroll)
    document.removeEventListener("scroll", this.onScroll, { capture: true })
    clearTimeout(this.hideTimer)
  }

  scrollTop(event) {
    event.preventDefault()
    this.dispatchKey("t")
  }

  scrollBottom(event) {
    event.preventDefault()
    this.dispatchKey("n")
  }

  onScroll() {
    const currentScrollY = window.scrollY
    const delta = currentScrollY - this.lastScrollY
    this.lastScrollY = currentScrollY

    if (Math.abs(delta) < 12) return

    if (delta > 0 && !this.nearBottom()) {
      this.showBottom()
    } else if (delta < 0 && !this.nearTop()) {
      this.showTop()
    } else {
      this.hideButtons()
    }
  }

  showTop() {
    if (!this.hasTopTarget || !this.hasBottomTarget) return

    this.showButton(this.topTarget)
    this.hideButton(this.bottomTarget)
    this.scheduleHide()
  }

  showBottom() {
    if (!this.hasTopTarget || !this.hasBottomTarget) return

    this.showButton(this.bottomTarget)
    this.hideButton(this.topTarget)
    this.scheduleHide()
  }

  hideButtons() {
    if (this.hasTopTarget) this.hideButton(this.topTarget)
    if (this.hasBottomTarget) this.hideButton(this.bottomTarget)
  }

  scheduleHide() {
    clearTimeout(this.hideTimer)
    this.hideTimer = setTimeout(() => this.hideButtons(), 900)
  }

  nearTop() {
    return window.scrollY < 120
  }

  nearBottom() {
    return window.innerHeight + window.scrollY >= document.body.scrollHeight - 120
  }

  dispatchKey(key) {
    document.dispatchEvent(new KeyboardEvent("keyup", { key, bubbles: true }))
  }

  showButton(element) {
    element.style.display = "flex"
    element.style.visibility = "visible"
    element.classList.remove("opacity-0", "translate-y-2", "pointer-events-none")
  }

  hideButton(element) {
    element.style.visibility = "hidden"
    element.classList.add("opacity-0", "translate-y-2", "pointer-events-none")
  }
}
