import { Controller } from '@hotwired/stimulus'

// WHERE CREDITS ARE DUE: This only became a stimulus controller due to the nature of TurboFrame
// <script src="https://unpkg.com/@material-tailwind/html@latest/scripts/tabs.js"></script>
//
// Connects to data-controller='flash'
export default class extends Controller {
  dismiss() {
    this.element.parentNode.removeChild(this.element)
  }
}
