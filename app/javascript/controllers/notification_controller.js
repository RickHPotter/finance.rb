import Notification from 'stimulus-notification'

// Connects to data-controller='notification'
export default class extends Notification {
  static values = {
    ...Notification.values,
    sticky: { type: Boolean, default: false }
  }

  connect() {
    super.connect()
  }

  show() {
    this.enter()

    if (this.stickyValue) return

    this.timeout = setTimeout(this.hide, this.delayValue)
  }
}
