import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["hiddenInput", "dateInput", "timeInput", "weekdayLabel"]
  static values = { invalidTimeMessage: String, maxDatetime: String, maxDatetimeMessage: String }

  connect() {
    this.handleFormSubmit = this.handleFormSubmit.bind(this)
    this.skipSubmitOnNextSync = false
    this.syncVisibleFromHidden()
    this.updateWeekdayLabel()
    this.hiddenInputTarget.form?.addEventListener("submit", this.handleFormSubmit)
  }

  disconnect() {
    this.hiddenInputTarget.form?.removeEventListener("submit", this.handleFormSubmit)
  }

  formatTimeInput() {
    if (!this.hasTimeInputTarget) return

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
      this.updateWeekdayLabel()
      return
    }

    const parsedTime = this.parseTime(this.currentTimeInputValue(), this.currentTimeValue())
    if (!parsedTime) {
      this.setInvalidTime()
      return
    }

    this.clearValidity()
    if (this.hasTimeInputTarget) this.timeInputTarget.value = parsedTime
    this.updateWeekdayLabel()

    const nextValue = `${nextDate}T${parsedTime}`
    if (!this.withinAllowedRange(nextValue)) {
      this.setInvalidMax()
      this.showMessage("alert", this.maxDatetimeMessageValue)
      return
    }

    if (this.hiddenInputTarget.value === nextValue) return

    this.clearDateValidity()
    this.hiddenInputTarget.value = nextValue
    if (this.skipSubmitOnNextSync) {
      this.skipSubmitOnNextSync = false
      return
    }

    this.hiddenInputTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.hiddenInputTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  handleKeydown(event) {
    if (event.key === "Tab") {
      this.skipSubmitOnNextSync = true
      return
    }

    if (event.key !== "Enter") return

    event.preventDefault()
    this.sync()

    if (this.dateInputTarget.validationMessage || this.timeValidationMessagePresent()) return

    this.hiddenInputTarget.form?.requestSubmit()
  }

  syncVisibleFromHidden() {
    const value = this.hiddenInputTarget.value
    if (!value) {
      this.updateWeekdayLabel()
      return
    }

    const [datePart, timePart] = value.split("T")
    this.dateInputTarget.value = datePart || ""
    if (this.hasTimeInputTarget) {
      this.timeInputTarget.value = timePart ? timePart.slice(0, 5) : ""
      this.formatTimeInput()
    }
    this.updateWeekdayLabel()
  }

  currentDateValue() {
    return this.dateInputTarget.value || this.hiddenInputTarget.value.split("T")[0] || ""
  }

  currentTimeValue() {
    return this.hiddenInputTarget.value.split("T")[1]?.slice(0, 5) || "00:00"
  }

  currentTimeInputValue() {
    return this.hasTimeInputTarget ? this.timeInputTarget.value : ""
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
    if (!this.hasTimeInputTarget) return

    this.timeInputTarget.setCustomValidity(this.invalidTimeMessageValue)
    this.timeInputTarget.reportValidity()
  }

  clearValidity() {
    if (!this.hasTimeInputTarget) return

    this.timeInputTarget.setCustomValidity("")
  }

  clearDateValidity() {
    this.dateInputTarget.setCustomValidity("")
  }

  updateWeekdayLabel() {
    if (!this.hasWeekdayLabelTarget) return

    const dateValue = this.currentDateValue()
    if (!dateValue) {
      this.weekdayLabelTarget.textContent = ""
      return
    }

    const weekday = this.weekdayFormatter().format(this.dateFromInputValue(dateValue))
    this.weekdayLabelTarget.textContent = weekday
  }

  weekdayFormatter() {
    return new Intl.DateTimeFormat(this.locale(), { weekday: "long" })
  }

  locale() {
    return window.APP_LOCALE || document.documentElement.lang || navigator.language || "en"
  }

  dateFromInputValue(value) {
    const [year, month, day] = value.split("-").map(number => parseInt(number, 10))
    return new Date(year, month - 1, day)
  }

  handleFormSubmit(event) {
    this.sync()
    if (this.dateInputTarget.validationMessage || this.timeValidationMessagePresent()) {
      event.preventDefault()
    }
  }

  timeValidationMessagePresent() {
    if (!this.hasTimeInputTarget) return false

    this.timeInputTarget.validationMessage
  }

  withinAllowedRange(nextValue) {
    if (!this.hasMaxDatetimeValue || !this.maxDatetimeValue) return true

    return this.dateTimeFromValue(nextValue) <= this.dateTimeFromValue(this.maxDatetimeValue)
  }

  dateTimeFromValue(value) {
    const [datePart, timePart = "00:00"] = value.split("T")
    const [year, month, day] = datePart.split("-").map(number => parseInt(number, 10))
    const [hour, minute] = timePart.split(":").map(number => parseInt(number, 10))
    return new Date(year, month - 1, day, hour, minute)
  }

  setInvalidMax() {
    this.dateInputTarget.setCustomValidity(this.maxDatetimeMessageValue)
    this.dateInputTarget.reportValidity()
  }

  showMessage(type, message) {
    const frame = document.querySelector("turbo-frame#notification")
    if (!frame) return

    frame.src = `static/notification?${type}=${encodeURIComponent(message)}`
  }
}
