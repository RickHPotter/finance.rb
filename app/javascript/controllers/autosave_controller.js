import Autosave from "stimulus-rails-autosave"

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
  }
}
