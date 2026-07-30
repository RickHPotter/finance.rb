import { Controller } from "@hotwired/stimulus"
import { previewReady, uniqueOwnerIds } from "../lib/allocation_mutation_state.mjs"

export default class extends Controller {
  static targets = [
    "actionButton",
    "allocationType",
    "configuration",
    "destinationId",
    "emptyState",
    "form",
    "loading",
    "operation",
    "ownerIds",
    "panel",
    "previewButton",
    "previewFrame",
    "rowCount",
    "sourceId"
  ]

  static values = { defaultAction: String }

  connect() {
    this.selectedAction = this.defaultActionValue || "category_add"
    this.onBeforeStreamRender = this.beforeStreamRender.bind(this)
    document.addEventListener("turbo:before-stream-render", this.onBeforeStreamRender)
    this.updateActionState()
    this.updatePreviewAvailability()
  }

  disconnect() {
    document.removeEventListener("turbo:before-stream-render", this.onBeforeStreamRender)
  }

  loadSelection({ ownerIds = [], selectedRowCount = 0 } = {}) {
    this.ownerIdsTarget.value = uniqueOwnerIds(ownerIds).join(",")
    this.rowCountTarget.value = String(selectedRowCount)
    this.backToForm()
    this.updatePreviewAvailability()
  }

  selectAction(event) {
    this.selectedAction = event.currentTarget.dataset.allocationActionKey
    this.allocationTypeTarget.value = event.currentTarget.dataset.allocationType
    this.operationTarget.value = event.currentTarget.dataset.allocationOperation
    this.sourceIdTarget.value = ""
    this.destinationIdTarget.value = ""
    this.updateActionState()
    this.syncAllocationValues()
    this.updatePreviewAvailability()
  }

  allocationChanged() {
    this.syncAllocationValues()
    this.updatePreviewAvailability()
  }

  previewStarted(event) {
    if (!this.previewReady()) {
      event.preventDefault()
      this.updatePreviewAvailability()
      return
    }

    this.previewResponseRendered = false
    this.configurationTarget.classList.add("hidden")
    this.previewFrameTarget.classList.add("hidden")
    this.loadingTarget.classList.remove("hidden")
  }

  previewFinished(event) {
    if (event.detail.success || this.previewResponseRendered) return

    this.loadingTarget.classList.add("hidden")
    this.configurationTarget.classList.remove("hidden")
  }

  backToForm() {
    if (!this.hasConfigurationTarget) return

    this.loadingTarget.classList.add("hidden")
    this.configurationTarget.classList.remove("hidden")
    if (this.hasPreviewFrameTarget) {
      this.previewFrameTarget.classList.add("hidden")
      this.previewFrameTarget.innerHTML = ""
    }
  }

  close(event) {
    this.backToForm()

    const modalElement = event.currentTarget.closest("[role='dialog']")
    if (!modalElement) return

    window.FlowbiteInstances?.getInstance("Modal", modalElement.id)?.hide()
  }

  beforeStreamRender(event) {
    const stream = event.target
    if (stream.target !== "allocation_mutation_preview") return
    if (!this.element.contains(document.getElementById("allocation_mutation_preview"))) return

    const originalRender = event.detail.render
    event.detail.render = async (streamElement) => {
      await originalRender(streamElement)
      this.previewRendered()
    }
  }

  previewRendered() {
    this.previewResponseRendered = true
    this.loadingTarget.classList.add("hidden")
    this.configurationTarget.classList.add("hidden")
    if (this.hasPreviewFrameTarget) this.previewFrameTarget.classList.remove("hidden")

    const appliedResult = this.element.querySelector("[data-allocation-mutation-applied='true']")
    if (appliedResult) {
      this.datatableController()?.clearSelection()
      this.element.dispatchEvent(new CustomEvent("allocation-mutation:applied", {
        bubbles: true,
        detail: { ownerIds: this.resultOwnerIds(appliedResult) }
      }))
    }
  }

  updateActionState() {
    this.actionButtonTargets.forEach((button) => {
      button.setAttribute("aria-pressed", String(button.dataset.allocationActionKey === this.selectedAction))
    })
    this.panelTargets.forEach((panel) => {
      panel.classList.toggle("hidden", panel.dataset.allocationActionKey !== this.selectedAction)
    })
  }

  syncAllocationValues() {
    const activePanel = this.panelTargets.find((panel) => panel.dataset.allocationActionKey === this.selectedAction)
    const source = activePanel?.querySelector("input[data-allocation-role='source']:checked")
    const destination = activePanel?.querySelector("input[data-allocation-role='destination']:checked")

    this.sourceIdTarget.value = source?.value || ""
    this.destinationIdTarget.value = destination?.value || ""
  }

  updatePreviewAvailability() {
    const hasOwners = this.ownerIds().length > 0 && Number(this.rowCountTarget.value) > 0
    this.emptyStateTarget.classList.toggle("hidden", hasOwners)
    this.previewButtonTarget.disabled = !this.previewReady()
  }

  previewReady() {
    return previewReady({
      ownerIds: this.ownerIds(),
      selectedRowCount: this.rowCountTarget.value,
      operation: this.operationTarget.value,
      sourceId: this.sourceIdTarget.value,
      destinationId: this.destinationIdTarget.value
    })
  }

  ownerIds() {
    return this.ownerIdsTarget.value.split(",").map((value) => value.trim()).filter(Boolean)
  }

  resultOwnerIds(resultElement) {
    try {
      return JSON.parse(resultElement.dataset.allocationMutationOwnerIds || "[]")
    } catch (_) {
      return []
    }
  }

  datatableController() {
    const table = this.element.closest("[data-controller~='datatable']")
    if (!table) return null

    return this.application.getControllerForElementAndIdentifier(table, "datatable")
  }
}
