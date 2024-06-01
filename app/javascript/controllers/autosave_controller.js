import Autosave from 'stimulus-rails-autosave'

// Connects to data-controller='autosave'
export default class extends Autosave {
  static targets = ["input"]
  static values = {
    delay: {
      type: Number,
      default: 1500,
    },
  }

  connect() {
    super.connect()
    const inputs_with_placeholder = this.inputTargets.filter(e => e.dataset.placeholder)
    inputs_with_placeholder.forEach(e => this.load(e))
  }

  load(input) {
    const symbol = "█"
    const text = input.dataset.placeholder

    const toggleBlink = () => {
      const lastChar = input.placeholder.at(-1)
      const cursor = lastChar === symbol ? " " : symbol
      input.placeholder = `${text}${cursor}`
    }

    const blinkInterval = setInterval(toggleBlink, 500)

    input.dataset.blinkInterval = blinkInterval;
  }

  old_load(input) {
    const split_method = input.dataset.placeholderType === "word" ? " " : ""
    const text_array = input.dataset.placeholder.split(split_method).concat([".", ".", "."])
    let index = 0

    function typeText() {
      if (index < text_array.length) {
        input.placeholder += text_array.at(index) + " "
        index++
        setTimeout(typeText, 300)
      } else {
        setTimeout(() => {
          input.placeholder = ""
          index = 0
          typeText()
        }, 3000)
      }
    }

    typeText()
  }
}
