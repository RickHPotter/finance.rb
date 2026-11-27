import { Controller } from "@hotwired/stimulus"

const active_bg = [ "bg-blue-200", "text-blue-900", "dark:bg-sky-900", "dark:text-sky-100" ]
const inactive_bg = [ "bg-slate-100", "text-slate-900", "dark:bg-slate-900", "dark:text-slate-200" ]

export default class extends Controller {
  static targets = ["monthYearContainer", "monthYear", "monthYears", "defaultYear"]
  static values = { soloHintMessage: String }

  connect() {
    this.initialise()
    this.isMouseDown = false;
    this.buttonStart = null
    this.buttonEnd = null
    this.shiftPressed = false
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

      if (count <= 0) {
        if (!this.activeMonths.has(month)) return

        this.activeMonths.delete(month)
        delete button.dataset.active
        button.classList.remove(...active_bg)
        button.classList.add(...inactive_bg)
        changed = true
        return
      }

      if (this.activeMonths.has(month)) return

      this.activeMonths.add(month)
      button.dataset.active = "true"
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
      button.dataset.active = "true"
    }
  }

  activate(event) {
    this.isMouseDown = true
    this.buttonStart = event.currentTarget
    this.shiftPressed = event.shiftKey
  }

  stop(event) {
    this.buttonEnd = event.currentTarget

    if (!this.buttonStart || !this.buttonEnd) return

    if (event.shiftKey || this.shiftPressed) {
      this._selectOnly(this.buttonEnd)
      this.isMouseDown = false
      this.shiftPressed = false
      return
    }

    const firstMonthYear = this.buttonStart.dataset.monthYear
    const lastMonthYear = this.buttonEnd.dataset.monthYear

    const buttonActive = "active" in this.buttonStart.dataset
    const previousActiveCount = this.activeMonths.size

    const buttonsToClick = this.monthYearTargets.filter(e => {
      return e.dataset.monthYear >= firstMonthYear && e.dataset.monthYear <= lastMonthYear && ("active" in e.dataset) === buttonActive
    })
    buttonsToClick.forEach(e => this.toggleMonth(e))

    if (buttonsToClick.length > 0) {
      if (buttonActive) this._maybeNotifySoloShortcut(previousActiveCount)
      this._syncFormState()
      document.getElementById(this.element.dataset.formId)?.requestSubmit()
    }

    this.isMouseDown = false
    this.shiftPressed = false
  }

  _selectOnly(targetButton) {
    let changed = false

    this.monthYearTargets.forEach(button => {
      const isTarget = button === targetButton
      const isActive = "active" in button.dataset

      if ((isTarget && !isActive) || (!isTarget && isActive)) {
        this.toggleMonth(button)
        changed = true
      }
    })

    if (!changed) return

    this._syncFormState()
    document.getElementById(this.element.dataset.formId)?.requestSubmit()
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
  }

  _removeMonthYearContainer(target, month) {
    this.activeMonths.delete(month)
    target.classList.remove(...active_bg)
    target.classList.add(...inactive_bg)

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

  _maybeNotifySoloShortcut(previousActiveCount) {
    if (!this.hasSoloHintMessageValue || !this.soloHintMessageValue) return
    if (!window.matchMedia?.("(hover: hover) and (pointer: fine)").matches) return

    const currentActiveCount = this.activeMonths.size
    const deactivatedOnlyActive = previousActiveCount === 1 && currentActiveCount === 0
    const narrowedToOne = previousActiveCount > 1 && currentActiveCount === 1
    if (!deactivatedOnlyActive && !narrowedToOne) return

    const frame = document.querySelector("turbo-frame#notification")
    if (!frame) return

    const url = `/static/notification?notice=${encodeURIComponent(this.soloHintMessageValue)}`
    if (frame.getAttribute("src") === url) frame.reload()
    else frame.src = url
  }
}
