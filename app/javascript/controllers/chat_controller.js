import { Controller } from "@hotwired/stimulus"
import RailsDate from "../models/railsDate"

// Connects to data-controller="chat"
export default class extends Controller {
  static targets = ["scroll", "messageTime", "messageAlignment", "messageColour", "messageAction", "input", "form"]

  connect() {
    this.localiseDates()
    this.scrollToBottom()
    this.showMessage()
  }

  localiseDates() {
    this.messageTimeTargets.forEach((el) => {
      const date = new RailsDate(el.dataset.timestamp)
      el.textContent = date.humanisedDateTime()
    })
  }

  scrollToBottom() {
    let scrollTarget = ""
    scrollTarget = this.hasScrollTarget ? this.scrollTarget : this.element.closest("[ data-chat-target='scroll' ]")

    scrollTarget.scrollTop = scrollTarget.scrollHeight
  }

  showMessage() {
    if (!this.hasMessageAlignmentTarget) { return }

    const element = this.element
    const currentUserId = document.querySelector("meta[name='current-user-id']").content
    const messageUserId = element.dataset.userId
    const presenterRole = element.dataset.presenterRole
    const presenterSide = element.dataset.presenterSide

    if (presenterRole === "assistant") {
      if (presenterSide === "self") {
        this.messageAlignmentTarget.classList.add("justify-end")
        this.messageColourTarget.classList.add("bg-emerald-50", "text-stone-900", "rounded-br-none", "border", "border-emerald-200")
        if (this.hasMessageActionTarget) { this.messageActionTarget.classList.add("hidden") }
      } else {
        this.messageAlignmentTarget.classList.add("justify-start")
        this.messageColourTarget.classList.add("bg-amber-50", "text-stone-900", "rounded-bl-none", "border", "border-amber-200")
        if (this.hasMessageActionTarget) { this.messageActionTarget.classList.remove("hidden") }
      }
    } else if (currentUserId === messageUserId) {
      this.messageAlignmentTarget.classList.add("justify-end")
      this.messageColourTarget.classList.add("bg-blue-500", "text-white", "rounded-br-none")
      if (this.hasMessageActionTarget) { this.messageActionTarget.classList.add("hidden") }
    } else {
      this.messageAlignmentTarget.classList.add("justify-start")
      this.messageColourTarget.classList.add("bg-gray-300", "text-gray-900", "rounded-bl-none")
      if (this.hasMessageActionTarget) { this.messageActionTarget.classList.remove("hidden") }
    }

    if (!this.hasMessageTarget) { return }

    this.scrollToBottom()
  }

  sendOnEnter(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      this.formTarget.requestSubmit()
      this.inputTarget.value = ""
    }
  }
}
