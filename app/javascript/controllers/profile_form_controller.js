import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "firstName", "lastName", "displayName" ]

  updateDisplayName() {
    const first = this.firstNameTarget.value.trim()
    const last = this.lastNameTarget.value.trim()
    
    let display = `${first} ${last}`.trim()
    if (display === "") {
      display = "User"
    }
    
    this.displayNameTarget.textContent = display
  }
}
