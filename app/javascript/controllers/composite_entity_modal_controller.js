import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  open(event) {
    const trigger = event.currentTarget
    const key = trigger.dataset.lineItemKey
    const row = this.rowFor(key)
    const selectedEntity = row?.querySelector("input[name$='[entity_id]']:checked")
    const entityId = selectedEntity?.value

    if (!entityId) {
      event.preventDefault()
      return
    }

    this.activeEntityId = entityId
    const entityLabel = selectedEntity.dataset.text || "Entity"

    requestAnimationFrame(() => this.activateEntity(key, entityId, entityLabel))
  }

  activateEntity(key, entityId, entityLabel) {
    this.groups().forEach(group => {
      const lineItemKey = group.dataset.lineItemKey
      const lineItemEntity = this.entityFor(lineItemKey)
      const shouldShow = Boolean(entityId) && lineItemEntity === entityId && this.lineItemIsActive(lineItemKey)

      group.dataset.entityId = lineItemEntity
      group.classList.toggle("hidden", !shouldShow)
      if (shouldShow) group.querySelector("input[name*='[_destroy]']").value = "false"
    })

    const title = this.element.querySelector("[data-composite-entity-modal-target~='title']")
    if (title) title.textContent = entityLabel
    this.refreshAggregate(entityId)
  }

  entityChanged(event) {
    const input = event.currentTarget
    const row = input.closest("[data-composite-transaction-target~='row']")
    if (!row) return

    const key = this.rowKey(row)
    const trigger = Array.from(this.element.querySelectorAll("[data-composite-entity-modal-target~='trigger']"))
      .find(button => button.dataset.lineItemKey === key)
    const entityId = input.value
    if (trigger) trigger.querySelector("button").disabled = !entityId

    const group = this.groups().find(element => element.dataset.lineItemKey === key)
    if (group) {
      group.dataset.entityId = entityId
      group.querySelector("input[name*='[_destroy]']").value = entityId ? "false" : "true"
    }

    if (this.activeEntityId) {
      this.activeEntityId = entityId
      this.activateEntity(key, entityId, input.dataset.text || "Entity")
    }
  }

  priceChanged(event) {
    const row = event.currentTarget.closest("[data-composite-transaction-target~='row']")
    if (!row) return

    const key = this.rowKey(row)
    const group = this.groups().find(element => element.dataset.lineItemKey === key)
    if (group) group.dataset.lineItemPrice = this.lineItemPrice(key).toString()
    if (this.activeEntityId) this.refreshAggregate(this.activeEntityId)
  }

  refreshAggregate(entityId = null) {
    const visibleGroups = this.groups().filter(group =>
      !group.classList.contains("hidden") && (!entityId || this.entityFor(group.dataset.lineItemKey) === entityId)
    )
    const cents = visibleGroups.reduce((total, group) => total + this.lineItemPrice(group.dataset.lineItemKey), 0)
    const aggregate = this.element.querySelector("[data-composite-entity-modal-target~='aggregate']")
    if (aggregate) aggregate.textContent = new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }).format(cents / 100)
  }

  rowFor(key) {
    return Array.from(document.querySelectorAll("[data-composite-transaction-target~='row']")).find(row => this.rowKey(row) === key)
  }

  rowKey(row) {
    return row.querySelector("input[name*='[line_items_attributes]']")?.name.match(/line_items_attributes\]\[([^\]]+)\]/)?.[1]
  }

  entityFor(key) {
    const row = this.rowFor(key)
    return row?.querySelector("input[name$='[entity_id]']:checked")?.value || ""
  }

  groups() {
    return Array.from(document.querySelectorAll("[data-composite-entity-modal-target~='group']"))
  }

  lineItemIsActive(key) {
    const row = this.rowFor(key)
    return row && row.querySelector("input[name*='[_destroy]']")?.value !== "1"
  }

  lineItemPrice(key) {
    const row = this.rowFor(key)
    const input = row?.querySelector("input[name$='[price]']")
    if (!input) return Number(this.groups().find(group => group.dataset.lineItemKey === key)?.dataset.lineItemPrice || 0)

    const cents = Number(input.value.replace(/[^\d-]/g, "")) || 0
    return input.dataset.sign === "-" && cents > 0 ? -cents : cents
  }
}
