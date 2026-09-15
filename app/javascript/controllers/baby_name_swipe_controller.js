import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card", "rejectForm", "acceptForm", "laterForm", "laterButton", "rejectStamp", "acceptStamp"]
  static values = {
    timeout: { type: Number, default: 5000 },
    laterLabel: { type: String, default: "Decide later" }
  }

  connect() {
    this.startTimers()
  }

  startTimers() {
    this.stopTimers()
    this.startedAt = performance.now()
    this.countdown = window.setInterval(() => this.renderCountdown(), 100)
    this.timeout = window.setTimeout(() => this.commit(this.laterFormTarget, "down"), this.timeoutValue)
  }

  disconnect() {
    this.stopTimers()
  }

  choose(event) {
    event.preventDefault()
    this.commit(event.currentTarget.form, event.currentTarget.dataset.direction)
  }

  reject(event) {
    if (this.ignoreKeyEvent(event)) return

    event.preventDefault()
    this.commit(this.rejectFormTarget, "left")
  }

  accept(event) {
    if (this.ignoreKeyEvent(event)) return

    event.preventDefault()
    this.commit(this.acceptFormTarget, "right")
  }

  later(event) {
    if (this.ignoreKeyEvent(event)) return

    event.preventDefault()
    this.commit(this.laterFormTarget, "down")
  }

  start(event) {
    if (this.committing) return

    this.dragging = true
    this.startX = event.clientX
    this.startY = event.clientY
    this.stopTimers()
    this.cardTarget.setPointerCapture(event.pointerId)
    this.cardTarget.style.transition = "none"
  }

  move(event) {
    if (!this.dragging || this.committing) return

    this.deltaX = event.clientX - this.startX
    this.deltaY = event.clientY - this.startY
    const rotation = this.deltaX / 18
    this.cardTarget.style.transform = `translate(${this.deltaX}px, ${this.deltaY * 0.18}px) rotate(${rotation}deg)`
    this.rejectStampTarget.style.opacity = Math.max(0, Math.min(1, -this.deltaX / 90))
    this.acceptStampTarget.style.opacity = Math.max(0, Math.min(1, this.deltaX / 90))
  }

  end() {
    if (!this.dragging || this.committing) return

    this.dragging = false
    if (this.deltaX <= -90) {
      this.commit(this.rejectFormTarget, "left")
    } else if (this.deltaX >= 90) {
      this.commit(this.acceptFormTarget, "right")
    } else {
      this.resetCard()
    }
  }

  cancel() {
    if (!this.dragging || this.committing) return

    this.dragging = false
    this.resetCard()
  }

  commit(form, direction) {
    if (this.committing) return

    this.committing = true
    this.stopTimers()
    this.element.querySelectorAll("button, input[type='submit']").forEach((control) => { control.disabled = true })
    this.cardTarget.style.transition = "transform 180ms ease-in, opacity 180ms ease-in"

    const transforms = {
      left: "translate(-125vw, 0) rotate(-24deg)",
      right: "translate(125vw, 0) rotate(24deg)",
      down: "translate(0, 70vh) scale(0.9)"
    }
    this.cardTarget.style.transform = transforms[direction]
    this.cardTarget.style.opacity = "0"

    window.setTimeout(() => form.requestSubmit(), 180)
  }

  resetCard() {
    this.deltaX = 0
    this.deltaY = 0
    this.cardTarget.style.transition = "transform 180ms ease-out"
    this.cardTarget.style.transform = ""
    this.rejectStampTarget.style.opacity = "0"
    this.acceptStampTarget.style.opacity = "0"
    this.startTimers()
  }

  renderCountdown() {
    const remaining = Math.max(0, this.timeoutValue - (performance.now() - this.startedAt))
    this.laterButtonTarget.value = `${this.laterLabelValue} · ${(remaining / 1000).toFixed(1)}s`
  }

  stopTimers() {
    window.clearInterval(this.countdown)
    window.clearTimeout(this.timeout)
  }

  ignoreKeyEvent(event) {
    return this.committing || ["INPUT", "TEXTAREA", "SELECT"].includes(event.target.tagName)
  }
}
