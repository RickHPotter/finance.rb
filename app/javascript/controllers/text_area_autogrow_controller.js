import TextAreaAutogrow from 'stimulus-textarea-autogrow'

// connects to data-controller='text-area-autogrow'
export default class extends TextAreaAutogrow {
  connect() {
    super.connect()
    this.element.classList.add('min-h-[4rem]')
  }
}
