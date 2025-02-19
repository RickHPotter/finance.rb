import { Controller } from "@hotwired/stimulus"

const active_bg = [ "bg-blue-200", "text-blue-800" ]
const inactive_bg = [ "bg-slate-100", "text-gray-800" ]

export default class extends Controller {
  static targets = ["monthYearContainer", "monthYear"]

  connect() {
    this.initialise()
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

  toggleMonth(event) {
    event.preventDefault()
    const month = parseInt(event.target.dataset.monthYear)

    if (document.activeMonths.has(month)) {
      this._removeMonthYearContainer(event.target, month)
    } else {
      this._addMonthYearContainer(event.target, month)
    }
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

    const parentFrame = document.querySelector("turbo-frame#month_year_container")
    const frame = document.createElement("turbo-frame")
    frame.id = `month_year_container_${month}`
    frame.src = `/card_transactions/month_year?month_year=${month}&user_card_id=${this.userCardId}`

    const currentFrames = Array.from(parentFrame.children)
                               .map(e => e.id.replace("month_year_container_", ""))
                               .map(Number)

    currentFrames.push(month)
    currentFrames.sort((a, b) => a - b)

    const index = currentFrames.indexOf(month)

    const nextSibling = parentFrame.querySelector(`#month_year_container_${currentFrames[index + 1]}`)

    if (nextSibling) {
      nextSibling.insertAdjacentElement("beforeBegin", frame)
    } else {
      parentFrame.appendChild(frame)
    }
  }

  _removeMonthYearContainer(target, month) {
    document.activeMonths.delete(month)
    target.classList.remove(...active_bg)
    target.classList.add(...inactive_bg)

    const frame = document.querySelector(`turbo-frame#month_year_container_${month}`)
    frame.remove()
  }
}
