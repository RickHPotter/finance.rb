import { Controller } from "@hotwired/stimulus"
import { initModals } from "flowbite"

export default class extends Controller {
  connect() {
    initModals()
  }

  selectCashTransaction(event) {
    const cashTransactionId = event.target.dataset.cashTransactionId
    const formIndex = event.target.dataset.formIndex
    document.getElementById(`cash_transaction_id_${formIndex}`).value = cashTransactionId
    this.modalTarget.classList.add("hidden")
  }
}
