import NestedForm from 'stimulus-rails-nested-form'

// Connects to data-controller='nested-form'
export default class extends NestedForm {
  static targets = ["target", "template"]

  connect() {
    super.connect()
  }

  add(e) {
    e.preventDefault()

    const content = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, new Date().getTime().toString())
    const insertPosition = this.targetTarget.dataset.nestedFormInsert || "beforebegin"
    this.targetTarget.insertAdjacentHTML(insertPosition, content)

    const event = new CustomEvent("rails-nested-form:add", { bubbles: true })
    this.element.dispatchEvent(event)
  }
}
