import { Controller } from "@hotwired/stimulus"

// Connects to data-controller='dynamic-description'
export default class extends Controller {
  static targets = ["description", "category", "entity", "monthYear", "value", "inclusive"]

  connect() {
    this.locale = window.APP_LOCALE || "fr"
  }

  updateDescription() {
    const inclusive = this.inclusiveTarget.checked
    const separator = inclusive ? " && " : " || "
    const categories_and_or_entities = [this.getCategories(), this.getEntities()].filter((value) => value !== "").join(separator)

    this.descriptionTarget.value = `${categories_and_or_entities} - ${this.getMonthYear()}`
  }

  getCategories() {
    if (this.categoryTargets.length === 0) { return "" }

    return `[ ${this.categoryTargets.map((category) => category.innerText).join(" | ")} ]`
  }

  getEntities() {
    if (this.entityTargets.length === 0) { return "" }

    return `( ${this.entityTargets.map((entity) => entity.innerText).join(" | ")} )`
  }

  getMonthYear() {
    if (!this.monthYearTarget.value) { return "" }

    const formatAbbr = new Intl.DateTimeFormat(this.locale, { year: "numeric", month: "long" })
    const year_month = this.monthYearTarget.value.split("-").map((value) => parseInt(value))
    const monthYearDate = new Date(year_month[0], year_month[1] - 1, 1)

    return this.capitalizeFirstLetter(formatAbbr.format(monthYearDate))
  }

  capitalizeFirstLetter(string) {
    return string[0].toUpperCase() + string.slice(1);
  }
}
