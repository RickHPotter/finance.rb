import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="form-validate"
export default class extends Controller {
  connect() {
    console.log(self.parentElement)
  }
}
