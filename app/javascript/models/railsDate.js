function getMonthNames(locale = "fr") {
  const formatFull = new Intl.DateTimeFormat(locale, { month: "long" })
  const formatAbbr = new Intl.DateTimeFormat(locale, { month: "short" })

  return {
    full: [...Array(12)].map((_, i) => formatFull.format(new Date(2000, i, 1))),
    abbr: [...Array(12)].map((_, i) => formatAbbr.format(new Date(2000, i, 1)).replace(".", "")),
  }
}

const locale = window.APP_LOCALE || "fr"
const { full: MONTHS_FULL, abbr: MONTHS_ABBR } = getMonthNames(locale)

class RailsDate {
  // Thanks, Javascript, for not supporting keyword parameters neither more than one constructor
  // Platypus variable can either be
  //   - an integer that represents year
  //   - a string that represents the whole date
  //   - another RailsDate you can use as base
  constructor(platypus, month = null, day = null, hour = null, minute = null) {
    switch (platypus.constructor) {
      case String:
        const [datePart, timePart] = platypus.split("T")
        const [yearDate, monthDate, dayDate] = datePart.split("-").map(Number)
        let hourDate = 0, minuteDate = 0
        if (timePart) {
          [hourDate, minuteDate] = timePart.split(":").map(Number)
        }
        this._applyDate(new Date(yearDate, monthDate - 1, dayDate, hourDate, minuteDate))
        break
      case RailsDate:
        this._applyDate(platypus.date())
        break
      case Number:
        this._applyDate(new Date(platypus, (month || 1) - 1, day || 1, hour || 0, minute || 0))
        break
    }
  }

  static today() {
    return new Date().toISOString().slice(0, 10)
  }

  date() {
    return new Date(this._date)
  }

  dateTime() {
    const proposedDate = this.date()
    const yyyy = proposedDate.getFullYear()
    const mm = String(proposedDate.getMonth() + 1).padStart(2, '0')
    const dd = String(proposedDate.getDate()).padStart(2, '0')
    const hh = String(proposedDate.getHours()).padStart(2, '0')
    const min = String(proposedDate.getMinutes()).padStart(2, '0')

    return `${yyyy}-${mm}-${dd}T${hh}:${min}`
  }

  monthYear() {
    if (!this.year)  { return }
    if (!this.month) { return }

    return `${MONTHS_ABBR[this.month - 1].toUpperCase()} <${this.year % 100}>`
  }

  monthName() {
    return MONTHS_FULL[this.month - 1]
  }

  yearsBackwards(years) {
    return this.yearsForwards(years * -1)
  }

  yearsForwards(years) {
    const newDate = new Date(this._date)
    newDate.setFullYear(this._date.getFullYear() + years)
    this._applyDate(newDate)

    return this
  }

  monthsBackwards(months) {
    return this.monthsForwards(months * -1)
  }

  monthsForwards(months) {
    const newDate = new Date(this._date)
    newDate.setMonth(this._date.getMonth() + months)
    this._applyDate(newDate)

    return this
  }

  daysBackwards(days) {
    return this.daysForwards(days * -1)
  }

  daysForwards(days) {
    const newDate = new Date(this._date)
    newDate.setDate(this._date.getDate() + days)
    this._applyDate(newDate)

    return this
  }

  setYear(year) {
    this.year = year
    this._date.setFullYear(year)

    return this
  }

  setMonth(month) {
    this.month = month
    this._date.setMonth(month - 1)

    return this
  }

  setDay(day) {
    this.day = day
    this._date.setDate(day)

    return this
  }

  _applyDate(date) {
    this.year = date.getFullYear()
    this.month = date.getMonth() + 1
    this.day = date.getDate()
    this.hour = date.getHours()
    this.minute = date.getMinutes()

    this._date = date
  }
}

export default RailsDate
