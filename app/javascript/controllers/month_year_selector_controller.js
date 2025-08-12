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

    const active   = this.monthYearContainerTargets.find(e => e.classList.contains("active"))
    const inactive = this.monthYearContainerTargets.filter(e => e !== active)

    this.defaultYear = active.dataset.year
    inactive.forEach(e => e.classList.add("hidden"))
    this.userCardId = document.querySelector("turbo-frame#month_year_container").dataset.userCardId
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

    const chosenMonthYear = this.monthYearContainerTargets.find(e => parseInt(e.dataset.year) === this.defaultYear)
    if (chosenMonthYear) {
      chosenMonthYear.classList.remove("hidden")
      chosenMonthYear.classList.add("active")
    }
  }

  _addMonthYearContainer(target, month) {
    this.activeMonths.add(month)
    target.classList.remove(...inactive_bg)
    target.classList.add(...active_bg)

    this.monthYearsTarget.value = JSON.stringify(Array.from(this.activeMonths))
    this.defaultYearTarget.value = this.defaultYear

    const formId = this.element.dataset.formId
    const form = document.getElementById(formId)
    form.requestSubmit()
  }

  _removeMonthYearContainer(target, month) {
    this.activeMonths.delete(month)
    target.classList.remove(...active_bg)
    target.classList.add(...inactive_bg)

    this.monthYearsTarget.value = JSON.stringify(Array.from(this.activeMonths))

    const frame = document.querySelector(`turbo-frame#month_year_container_${month}`)
    if (frame) {
      frame.remove()
      document.dispatchEvent(new Event("turbo:frame-load"))
    }
  }
}
