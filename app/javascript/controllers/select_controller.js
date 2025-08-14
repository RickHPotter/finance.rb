import { Controller } from "@hotwired/stimulus"
import TomSelect from "tom-select"

export default class extends Controller {
  connect() {
    if (this.element.dataset.id == "cash-transaction-select") {
      this.initialiseCashTransactionSelect(entityId)
    } else {
      this.initializeTomSelect()
    }
  }

  initializeTomSelect() {
    const tom = new TomSelect(this.element, {
      plugins: {
        remove_button:{ title: "Remove this item" },
        clear_button: { title: "Remove all selected options" },
      },
      persist: false,
      allowEmptyOption: true,
      placeholder: this.element.dataset.placeholder
    })

    tom.on("item_add", () => {
      tom.setTextboxValue("")
      tom.refreshOptions(false)
    })

    if (!this.element.querySelector(".clear-button")) { return }

    this.element.querySelector(".clear-button").addEventListener("click", () => {
      this.element.querySelector("select").dispatchEvent(new Event("change"))
    })
  }

  initialiseCashTransactionSelect(entityId) {
    if (!entityId) return

    new TomSelect(this.element, {
      valueField: "id",
      labelField: "description",
      searchField: "description",
      load: function(query, callback) {
        var url = `/cash_transactions/inspect?entity_id=${entityId}&query=` + encodeURIComponent(query)
        fetch(url)
          .then(response => response.json())
          .then(json => {
            callback(json)
          }).catch(()=>{
            callback()
          })
      },
      render: {
        option: function(item, escape) {
          if (!item.categories) { return "<div class='opacity-0'></div>" }

          return `<div class="rounded-lg shadow-sm overflow-hidden ${ escape(item.bg_colour) } my-1">
            <div class="px-4 py-2">
              <div class="grid grid-cols-4 md:grid-cols-9 gap-2 w-full text-black text-sm font-semibold">
                <span class="p-1 rounded-sm bg-transparent border border-black">
                  ${ escape(item.date) }
                </span>

                <div class="col-span-4 ps-4 flex items-center gap-2">
                  <span class="p-1 rounded-sm bg-white border border-black ${ escape(parseInt(item.cash_installments_count) == 1) ? 'opacity-40' : ''}">
                    ${ escape(item.pretty_installments) }
                  </span>
                  <span class="col-span-2 truncate text-md">${ escape(item.description) }</span>
                </div>

                <div class="col-span-3 flex items-center gap-2">
                  ${ item.categories.map(category => `<span class="px-2 py-1 rounded-sm border-1 border-black text-sm">${ escape(category) }</span>`).join('') }
                </div>

                <span class="p-1 rounded-sm text-end">${ escape(item.price) }</span>
              </div>
            </div>
          </div>`
        },
        item: function(item, escape) {
          if (!item.categories) { return "<div class='opacity-0'></div>" }

          return `<div class="rounded-lg shadow-sm overflow-hidden ${ escape(item.bg_colour) } my-1">
            <div class="px-4 py-2">
              <div class="grid grid-cols-4 md:grid-cols-9 gap-2 w-full text-black text-sm font-semibold">
                <span class="p-1 rounded-sm bg-transparent border border-black">
                  ${ escape(item.date) }
                </span>

                <div class="col-span-4 ps-4 flex items-center gap-2">
                  <span class="p-1 rounded-sm bg-white border border-black ${ escape(parseInt(item.cash_installments_count) == 1) ? 'opacity-40' : ''}">
                    ${ escape(item.pretty_installments) }
                  </span>
                  <span class="col-span-2 truncate text-md">${ escape(item.description) }</span>
                </div>

                <div class="col-span-3 flex items-center gap-2">
                  ${ item.categories.map(category => `<span class="px-2 py-1 rounded-sm border-1 border-black text-sm">${ escape(category) }</span>`).join('') }
                </div>

                <span class="p-1 rounded-sm text-end">${ escape(item.price) }</span>
              </div>
            </div>
          </div>`
        }
      },
    })
  }
}
