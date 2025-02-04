const MONTHS_FULL = ["Janvier", "Fevrier", "Mars", "Avril", "Mai", "June", "Jui", "Aout", "Septembre", "Octobre", "Novembre", "Decembre"]
const MONTHS_ABBR = ["Jan", "Fev", "Mars", "Avril", "Mai", "June", "Jui", "Aout", "Sept", "Oct", "Nov", "Dec"]

class RailsDate {
  // Thanks, Javascript, for not supporting keyword parameters neither more than one constructor
  // Platypus variable can either be
  //   - an integer that represents year
  //   - a string that represents the whole date
  //   - another RailsDate you can use as base
  constructor(platypus, month = null, day = null) {
    switch (platypus.constructor) {
      case String:
        this._applyDate(new Date(platypus.slice(0, 10) + "T00:00:00"))
        break
      case RailsDate:
        this._applyDate(platypus.date())
        break
      case Number:
        this._applyDate(new Date(platypus, (month || 1) - 1, day || 1))
        break
    }
  }

  static today() {
    return new Date().toISOString().slice(0, 10)
  }

  date() {
    return new Date(this._date)
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
    const new_date = new Date(this._date)
    new_date.setFullYear(this._date.getFullYear() + years)
    this._applyDate(new_date)

    return this
  }

  monthsBackwards(months) {
    return this.monthsForwards(months * -1)
  }

  monthsForwards(months) {
    const new_date = new Date(this._date)
    new_date.setMonth(this._date.getMonth() + months)
    this._applyDate(new_date)

    return this
  }

  daysBackwards(days) {
    return this.daysForwards(days * -1)
  }

  daysForwards(days) {
    const new_date = new Date(this._date)
    new_date.setDate(this._date.getDate() + days)
    this._applyDate(new_date)

    return this
  }

  setYear(year) {
    this.year = year
    this._date.setFullYear(year)

    return this
  }

  setMonth(month) {
    this.month = month
    this._date.setMonth(month)

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

    this._date = date
  }
}

export default RailsDate
