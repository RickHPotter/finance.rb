import NestedForm from 'stimulus-rails-nested-form'

// Connects to data-controller='nested-form'
export default class extends NestedForm {
   static targets = ["target", "template"]
  connect() {
    super.connect()
  }

  addChildNested(e) {
    e.preventDefault()

    const content = this.templateTarget.innerHTML.replace(/NEW_NESTED_RECORD/g, new Date().getTime().toString())
    this.targetTarget.insertAdjacentHTML("beforebegin", content)

    const event = new CustomEvent("rails-nested-form:add", { bubbles: true })
    this.element.dispatchEvent(event)
  }
}
