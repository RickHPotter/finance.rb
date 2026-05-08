import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["hour", "minute"]
  static values = { inputId: String, time: String }

  connect() {
    this.input = document.querySelector(this.inputIdValue)
    this.timeValue = this.normalizeTime(this.input?.value || this.timeValue || "00:00")
    this.render()
  }

  incrementHour() {
    this.changeHour(1)
  }

  decrementHour() {
    this.changeHour(-1)
  }

  incrementMinute() {
    this.changeMinute(1)
  }

  decrementMinute() {
    this.changeMinute(-1)
  }

  selectInput(event) {
    event.currentTarget.select()
  }

  editTime() {
    this.hourTarget.value = this.numericValue(this.hourTarget.value, 23)
    this.minuteTarget.value = this.numericValue(this.minuteTarget.value, 59)
    this.timeValue = this.format(this.inputNumber(this.hourTarget), this.inputNumber(this.minuteTarget))
    this.updateBackingInput()
  }

  commitEdit() {
    this.timeValue = this.format(this.inputNumber(this.hourTarget), this.inputNumber(this.minuteTarget))
    this.commit()
  }

  handleKeydown(event) {
    if (event.key !== "Enter") return

    event.preventDefault()
    this.commitEdit()
    event.currentTarget.blur()
  }

  changeHour(delta) {
    const [hour, minute] = this.parts()
    this.timeValue = this.format((hour + delta + 24) % 24, minute)
    this.commit()
  }

  changeMinute(delta) {
    const [hour, minute] = this.parts()
    const total = hour * 60 + minute + delta
    const wrapped = (total + 24 * 60) % (24 * 60)
    this.timeValue = this.format(Math.floor(wrapped / 60), wrapped % 60)
    this.commit()
  }

  commit() {
    this.render()
    this.updateBackingInput()
  }

  updateBackingInput() {
    if (!this.input) return

    this.input.value = this.timeValue
    this.input.dispatchEvent(new Event("input", { bubbles: true }))
    this.input.dispatchEvent(new Event("change", { bubbles: true }))
  }

  render() {
    const [hour, minute] = this.parts()
    this.hourTarget.value = hour.toString().padStart(2, "0")
    this.minuteTarget.value = minute.toString().padStart(2, "0")
  }

  parts() {
    return this.normalizeTime(this.timeValue).split(":").map((part) => parseInt(part, 10))
  }

  normalizeTime(value) {
    const match = value.match(/^(\d{1,2}):(\d{1,2})$/)
    if (!match) return "00:00"

    const hour = Math.min(Math.max(parseInt(match[1], 10), 0), 23)
    const minute = Math.min(Math.max(parseInt(match[2], 10), 0), 59)
    return this.format(hour, minute)
  }

  format(hour, minute) {
    return `${hour.toString().padStart(2, "0")}:${minute.toString().padStart(2, "0")}`
  }

  numericValue(value, max) {
    const digits = value.replace(/\D/g, "").slice(0, 2)
    if (digits === "") return ""

    return Math.min(parseInt(digits, 10), max).toString()
  }

  inputNumber(input) {
    const value = parseInt(input.value, 10)
    return Number.isNaN(value) ? 0 : value
  }
}
