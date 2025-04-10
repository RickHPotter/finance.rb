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
    document.activeMonths = new Set()

    this.monthYearTargets.forEach(e => {
      if (e.dataset.active == "true") {
        e.classList.add(...active_bg)
        document.activeMonths.add(parseInt(e.dataset.monthYear))
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

    if (document.activeMonths.has(month)) {
      this._removeMonthYearContainer(button, month)
      button.dataset.active = false
    } else {
      this._addMonthYearContainer(button, month)
      button.dataset.active = true
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

    const operation = this.buttonStart.dataset.active

    const buttonsToClick = this.monthYearTargets.filter(e => e.dataset.monthYear >= firstMonthYear && e.dataset.monthYear <= lastMonthYear && e.dataset.active === operation)
    buttonsToClick.forEach(e => this.toggleMonth(e))

    this.isMouseDown = false
  }

  _updateContainer() {
    this.monthYearContainerTargets.forEach(e => {
      e.classList.remove("active")
      e.classList.add("hidden")
    })

    const chosenMonthYear = this.monthYearContainerTargets.find(e => parseInt(e.dataset.year) === this.defaultYear)
    chosenMonthYear.classList.remove("hidden")
    chosenMonthYear.classList.add("active")
  }

  _addMonthYearContainer(target, month) {
    document.activeMonths.add(month)
    target.classList.remove(...inactive_bg)
    target.classList.add(...active_bg)

    this.monthYearsTarget.value = JSON.stringify(Array.from(document.activeMonths))
    this.defaultYearTarget.value = this.defaultYear

    const formId = this.element.dataset.formId
    const form = document.getElementById(formId)
    form.requestSubmit()
  }

  _removeMonthYearContainer(target, month) {
    document.activeMonths.delete(month)
    target.classList.remove(...active_bg)
    target.classList.add(...inactive_bg)

    const frame = document.querySelector(`turbo-frame#month_year_container_${month}`)
    frame.remove()
  }
}
