import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.initializeTomSelect()
  }

  initializeTomSelect() {
    new TomSelect(this.element, {
      plugins: {
        remove_button:{
          title:'Remove this item',
        },
        clear_button: {
          title:'Remove all selected options',
        },
      },
      persist: false,
      allowEmptyOption: true,
      placeholder: this.element.dataset.placeholder
    });
  }
}
