import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["hiddenInput", "dateInput", "timeInput"]
  static values = { invalidTimeMessage: String }

  connect() {
    this.syncVisibleFromHidden()
  }

  formatTimeInput() {
    const digits = this.timeInputTarget.value.replace(/\D/g, "").slice(0, 4)

    if (digits.length <= 2) {
      this.timeInputTarget.value = this.normalizePartialHour(digits)
      this.clearValidity()
      return
    }

    const normalizedHour = this.normalizePartialHour(digits.slice(0, 2))
    const normalizedMinute = this.normalizePartialMinute(digits.slice(2, 4))
    this.timeInputTarget.value = `${normalizedHour}:${normalizedMinute}`
    this.clearValidity()
  }

  sync() {
    const nextDate = this.currentDateValue()
    if (!nextDate) {
      this.clearValidity()
      this.hiddenInputTarget.value = ""
      return
    }

    const parsedTime = this.parseTime(this.timeInputTarget.value, this.currentTimeValue())
    if (!parsedTime) {
      this.setInvalidTime()
      return
    }

    this.clearValidity()
    this.timeInputTarget.value = parsedTime

    const nextValue = `${nextDate}T${parsedTime}`
    if (this.hiddenInputTarget.value === nextValue) return

    this.hiddenInputTarget.value = nextValue
    this.hiddenInputTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.hiddenInputTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  handleKeydown(event) {
    if (event.key !== "Enter") return

    event.preventDefault()
    this.sync()
  }

  syncVisibleFromHidden() {
    const value = this.hiddenInputTarget.value
    if (!value) return

    const [datePart, timePart] = value.split("T")
    this.dateInputTarget.value = datePart || ""
    this.timeInputTarget.value = timePart ? timePart.slice(0, 5) : ""
    this.formatTimeInput()
  }

  currentDateValue() {
    return this.dateInputTarget.value || this.hiddenInputTarget.value.split("T")[0] || ""
  }

  currentTimeValue() {
    return this.hiddenInputTarget.value.split("T")[1]?.slice(0, 5) || "00:00"
  }

  parseTime(value, fallback) {
    const raw = value.trim().replace(".", ":")
    if (raw === "") return fallback

    if (/^\d{1,2}:\d{2}$/.test(raw)) {
      return this.normalizeTime(raw)
    }

    if (/^\d{1,2}$/.test(raw)) {
      return this.normalizeTime(`${raw}:00`)
    }

    if (/^\d{3,4}$/.test(raw)) {
      const padded = raw.padStart(4, "0")
      return this.normalizeTime(`${padded.slice(0, 2)}:${padded.slice(2, 4)}`)
    }

    return null
  }

  normalizeTime(value) {
    const [hourString, minuteString] = value.split(":")
    const hour = parseInt(hourString, 10)
    const minute = parseInt(minuteString, 10)
    if (Number.isNaN(hour) || Number.isNaN(minute)) return null
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null

    return `${hour.toString().padStart(2, "0")}:${minute.toString().padStart(2, "0")}`
  }

  normalizePartialHour(value) {
    if (value === "") return ""
    if (value.length === 1) return value

    return Math.min(parseInt(value, 10), 23).toString().padStart(2, "0")
  }

  normalizePartialMinute(value) {
    if (value === "") return ""
    if (value.length === 1) return value

    return Math.min(parseInt(value, 10), 59).toString().padStart(2, "0")
  }

  setInvalidTime() {
    this.timeInputTarget.setCustomValidity(this.invalidTimeMessageValue)
    this.timeInputTarget.reportValidity()
  }

  clearValidity() {
    this.timeInputTarget.setCustomValidity("")
  }
}
