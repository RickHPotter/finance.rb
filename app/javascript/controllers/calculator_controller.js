import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="calculator"
export default class extends Controller {
  static targets = ["display", "history"]

  connect() {
    this.clear()
    this.history = []
  }

  append(event) {
    const value = event.currentTarget.dataset.value
    const operands = ["+", "-", "*", "/"]
    const lastChar = this.displayTarget.value.slice(-1)

    if (operands.includes(value) && operands.includes(lastChar)) {
      this.displayTarget.value = this.displayTarget.value.slice(0, -1) + value
    } else {
      this.displayTarget.value += value
    }
  }

  clear() {
    this.displayTarget.value = ""
  }

  delete() {
    this.displayTarget.value = this.displayTarget.value.slice(0, -1)
  }

  sanitizeInput(event) {
    event.target.value = event.target.value.replace(/[^0-9+\-*/.()]/g, "")

    const operands = ["+", "-", "*", "/"]
    const lastChars = event.target.value.slice(-2)

    if (lastChars.length === 2 && operands.includes(lastChars[0]) && operands.includes(lastChars[1])) {
      event.target.value = event.target.value.slice(0, -2) + lastChars[1]
    }
  }

  calculate() {
    this.removeMessage()

    try {
      const expression = this.displayTarget.value
      const operands = ["+", "-", "*", "/"]
      const operandsInExpression = operands.some(op => expression.includes(op))

      if (expression.trim() === "" || operandsInExpression === false) {
        return
      }

      let result = eval(expression)

      if (result === undefined) {
        this.showMessage("alert", "Oops. Undefined, bitch.")
        return
      } else {
        result = result.toFixed(2)
      }

      this.displayTarget.value = result
      this.addToHistory(expression, result)
    } catch (e) {
      this.showMessage("alert", "Oops. " + e.message)
    }
  }

  addToHistory(expression, result) {
    const entry = `${expression} = ${result}`
    this.history.unshift(entry)
    this.renderHistory()
  }

  renderHistory() {
    this.historyTarget.innerHTML = this.history
      .map(item => `<li class="border-b border-gray-200 py-1">${item}</li>`)
      .join("")
  }

  showMessage(type, message) {
    const frame = document.querySelector("turbo-frame#notification")
    frame.src = `pages/notification?${type}=${message}`
  }

  removeMessage() {
    const frame = document.querySelector("turbo-frame#notification")
    frame.innerHTML = ""
  }
}
