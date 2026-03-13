import { Controller } from "@hotwired/stimulus"

const active_bg = [ "bg-blue-200", "text-blue-800" ]
const inactive_bg = [ "bg-slate-100", "text-gray-800" ]

export default class extends Controller {
  static targets = ["monthYearContainer", "monthYear", "monthYears", "defaultYear"]

  connect() {
    this.initialise()
    this.isMouseDown = false;
    this.buttonStart = null
    this.buttonEnd = null
  }

  initialise() {
    this.activeMonths = new Set()

    this.monthYearTargets.forEach(e => {
      if ("active" in e.dataset) {
        e.classList.add(...active_bg)
        this.activeMonths.add(parseInt(e.dataset.monthYear))
      } else {
        e.classList.add(...inactive_bg)
      }
    })

    const active = this.monthYearContainerTargets.find(e => e.classList.contains("active")) || this.monthYearContainerTargets[0]
    if (!active) return

    const inactive = this.monthYearContainerTargets.filter(e => e !== active)

    this.defaultYear = parseInt(active.dataset.year, 10)
    inactive.forEach(e => e.classList.add("hidden"))
  }

  prevYear(event) {
    event.preventDefault()

    this.defaultYear--
    this._updateContainer()
  }

  nextYear(event) {
    event.preventDefault()

    this.defaultYear++
    this._updateContainer()
  }

  selectAll(event) {
    event.preventDefault()

    let changed = false

    this.monthYearTargets.forEach(button => {
      const month = parseInt(button.dataset.monthYear)
      const count = parseInt(button.dataset.count || "0")

      if (count <= 0 || this.activeMonths.has(month)) return

      this.activeMonths.add(month)
      button.dataset.active = ""
      button.classList.remove(...inactive_bg)
      button.classList.add(...active_bg)
      changed = true
    })

    if (!changed) return

    this._syncFormState()
    document.getElementById(this.element.dataset.formId)?.requestSubmit()
  }

  toggleMonth(button) {
    const month = parseInt(button.dataset.monthYear)

    if (this.activeMonths.has(month)) {
      this._removeMonthYearContainer(button, month)
      delete button.dataset.active
    } else {
      this._addMonthYearContainer(button, month)
      button.dataset.active = ""
    }
  }

  activate(event) {
    this.isMouseDown = true
    this.buttonStart = event.currentTarget
  }

  stop(event) {
    this.buttonEnd = event.currentTarget

    if (!this.buttonStart || !this.buttonEnd) return

    const firstMonthYear = this.buttonStart.dataset.monthYear
    const lastMonthYear = this.buttonEnd.dataset.monthYear

    const buttonActive = "active" in this.buttonStart.dataset

    const buttonsToClick = this.monthYearTargets.filter(e => {
      return e.dataset.monthYear >= firstMonthYear && e.dataset.monthYear <= lastMonthYear && ("active" in e.dataset) === buttonActive
    })
    buttonsToClick.forEach(e => this.toggleMonth(e))

    this.isMouseDown = false
  }

  _updateContainer() {
    this.monthYearContainerTargets.forEach(e => {
      e.classList.remove("active")
      e.classList.add("hidden")
    })

    const chosenMonthYear = this.monthYearContainerTargets.find(e => parseInt(e.dataset.year, 10) === this.defaultYear)
    if (chosenMonthYear) {
      chosenMonthYear.classList.remove("hidden")
      chosenMonthYear.classList.add("active")
    }
  }

  _addMonthYearContainer(target, month) {
    this.activeMonths.add(month)
    target.classList.remove(...inactive_bg)
    target.classList.add(...active_bg)
    this._syncFormState()

    const formId = this.element.dataset.formId
    const form = document.getElementById(formId)
    form?.requestSubmit()
  }

  _removeMonthYearContainer(target, month) {
    this.activeMonths.delete(month)
    target.classList.remove(...active_bg)
    target.classList.add(...inactive_bg)

    this._syncFormState()

    const frame = document.querySelector(`turbo-frame#month_year_container_${month}`)
    if (frame) {
      frame.remove()
      document.dispatchEvent(new Event("turbo:frame-load"))
    }
  }

  _syncFormState() {
    this.monthYearsTarget.value = JSON.stringify(Array.from(this.activeMonths))
    this.defaultYearTarget.value = this.defaultYear
  }
}
