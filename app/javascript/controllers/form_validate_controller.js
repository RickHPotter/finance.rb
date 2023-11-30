import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="form-validate"
export default class extends Controller {
  static targets = ['field']

  connect() {
    const invalid_fields = this.fieldTargets.filter(field => field.classList.contains('is-invalid'))

    invalid_fields.forEach((field) => {
      field.classList.remove('focus:ring-indigo-600')
      field.classList.add('ring-1', 'ring-red-500', 'focus:ring-red-600')

      const id = field.getAttribute('id')
      const label = self.document.querySelector('label[for="' + id + '"]')
      label.classList.remove('peer-focus:text-indigo-600')
      label.classList.add('peer-focus:text-red-600')
    })

    if (invalid_fields.length > 0) {
      invalid_fields[0].focus()
    }
  }
}
