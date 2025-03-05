import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="blinking-placeholder"
export default class extends Controller {
  connect() {
    this.blink_placeholder(this.element)
  }

  blink_placeholder(input) {
    const symbol = "█"
    const text = this.element.dataset.text

    const toggleBlink = () => {
      const lastChar = input.placeholder.at(-1)
      const cursor = lastChar === symbol ? " " : symbol
      input.placeholder = `${text}${cursor}`
    }

    const blinkInterval = setInterval(toggleBlink, 500)

    input.dataset.blinkInterval = blinkInterval;
  }
}
