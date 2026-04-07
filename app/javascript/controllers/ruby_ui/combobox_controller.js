import { Controller } from "@hotwired/stimulus";
import { computePosition, autoUpdate, offset, flip } from "@floating-ui/dom";

// Connects to data-controller="ruby-ui--combobox"
export default class extends Controller {
  static values = {
    term: String,
    reorder: Boolean
  }

  static targets = [
    "input",
    "toggleAll",
    "popover",
    "item",
    "emptyState",
    "searchInput",
    "trigger",
    "triggerContent"
  ]

  selectedItemIndex = null
  ignoreNextTriggerFocus = false

  connect() {
    this.updateTriggerContent()
    this.initializeOrderTracking()
  }

  disconnect() {
    if (this.cleanup) { this.cleanup() }
  }

  inputChanged(e) {
    const input = e.target
    this.updateTriggerContent()

    if (input.type == "radio") {
      this.closePopover()
    }

    if (this.hasToggleAllTarget && !input.checked) {
      this.toggleAllTarget.checked = false
    }

    if (this.reorderValue && this.isActualInput(input)) {
      this.updateSelectedOrder(input)
      this.reorderItems()
    }
  }

  inputContent(input) {
    return input.dataset.text || input.parentElement.textContent
  }

  toggleAllItems() {
    const isChecked = this.toggleAllTarget.checked
    this.inputTargets.forEach(input => input.checked = isChecked)
    this.updateTriggerContent()
    if (this.reorderValue) {
      if (isChecked) {
        this.selectedOrder = this.actualInputs().map(input => input.value)
      } else {
        this.selectedOrder = []
      }
      this.reorderItems()
    }
  }

  updateTriggerContent() {
    const checkedInputs = this.inputTargets.filter(input => input.checked)

    if (checkedInputs.length == 0) {
      this.triggerContentTarget.innerText = this.triggerTarget.dataset.placeholder
    } else if (checkedInputs.length === 1) {
      this.triggerContentTarget.innerText = this.inputContent(checkedInputs[0])
    } else {
      this.triggerContentTarget.innerText = `${checkedInputs.length} ${this.termValue}`
    }
  }

  openPopover(event) {
    if (event?.type === "focus" && this.ignoreNextTriggerFocus) {
      return
    }

    if (event?.type === "click") {
      event.preventDefault()
    }

    if (this.popoverTarget.matches(":popover-open")) {
      this.updatePopoverWidth()
      if (this.hasSearchInputTarget && event?.type === "focus") {
        requestAnimationFrame(() => {
          this.searchInputTarget.focus()
          this.searchInputTarget.select()
        })
      }
      return
    }

    this.updatePopoverPosition()
    this.updatePopoverWidth()
    this.triggerTarget.ariaExpanded = "true"
    this.popoverTarget.showPopover()
    this.highlightFirstVisibleItem()
    if (this.hasSearchInputTarget) {
      requestAnimationFrame(() => {
        this.searchInputTarget.focus()
        this.searchInputTarget.select()
      })
    }
  }

  closePopover() {
    this.triggerTarget.ariaExpanded = "false"
    this.popoverTarget.hidePopover()
  }

  filterItems(e) {
    if (["ArrowDown", "ArrowUp", "Tab", "Enter"].includes(e.key)) {
      return
    }

    const filterTerm = this.searchInputTarget.value.toLowerCase()

    if (this.hasToggleAllTarget) {
      if (filterTerm) this.toggleAllTarget.parentElement.classList.add("hidden")
      else this.toggleAllTarget.parentElement.classList.remove("hidden")
    }

    let resultCount = 0

    this.inputTargets.forEach((input) => {
      const text = this.inputContent(input).toLowerCase()

      if (text.indexOf(filterTerm) > -1) {
        input.parentElement.classList.remove("hidden")
        resultCount++
      } else {
        input.parentElement.classList.add("hidden")
      }
    })

    this.emptyStateTarget.classList.toggle("hidden", resultCount !== 0)
    this.highlightFirstVisibleItem()
  }

  keyDownPressed() {
    if (!this.popoverTarget.matches(":popover-open")) {
      this.openPopover()
      return
    }

    if (this.selectedItemIndex !== null) {
      this.selectedItemIndex++
    } else {
      this.selectedItemIndex = 0
    }

    this.focusSelectedInput()
  }

  keyUpPressed() {
    if (!this.popoverTarget.matches(":popover-open")) {
      this.openPopover()
      return
    }

    if (this.selectedItemIndex !== null) {
      this.selectedItemIndex--
    } else {
      this.selectedItemIndex = -1
    }

    this.focusSelectedInput()
  }

  focusSelectedInput() {
    const visibleInputs = this.inputTargets.filter(input => !input.parentElement.classList.contains("hidden"))
    if (visibleInputs.length === 0) {
      this.selectedItemIndex = null
      this.itemTargets.forEach(item => item.ariaCurrent = "false")
      return
    }

    this.wrapSelectedInputIndex(visibleInputs.length)

    visibleInputs.forEach((input, index) => {
      if (index == this.selectedItemIndex) {
        input.parentElement.ariaCurrent = "true"
        input.parentElement.scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'nearest' })
      } else {
        input.parentElement.ariaCurrent = "false"
      }
    })
  }

  keyEnterPressed(event) {
    event.preventDefault()
    const option = this.currentOption() || (this.hasSearchTerm() ? this.firstVisibleOption() : null)

    if (option) {
      this.activateOption(option)
    }
  }

  keyTabPressed(event) {
    if (event.key !== "Tab") { return }

    const option = this.currentOption() || (this.hasSearchTerm() ? this.firstVisibleOption() : null)
    const nextElement = this.adjacentElement({ backwards: event.shiftKey })

    event.preventDefault()
    event.stopPropagation()

    if (option) {
      this.activateOption(option)
    }

    this.ignoreNextTriggerFocus = true
    this.closePopover()

    requestAnimationFrame(() => {
      this.searchInputTarget?.blur()
      this.triggerTarget.blur()
      nextElement?.focus()
      requestAnimationFrame(() => {
        this.ignoreNextTriggerFocus = false
      })
    })
  }

  handleFocusOut(event) {
    if (event.relatedTarget && this.element.contains(event.relatedTarget)) { return }

    this.closePopover()
  }

  wrapSelectedInputIndex(length) {
    this.selectedItemIndex = ((this.selectedItemIndex % length) + length) % length
  }

  updatePopoverPosition() {
    this.cleanup = autoUpdate(this.triggerTarget, this.popoverTarget, () => {
      computePosition(this.triggerTarget, this.popoverTarget, {
        placement: 'bottom-start',
        middleware: [offset(4), flip()],
      }).then(({ x, y }) => {
        Object.assign(this.popoverTarget.style, {
          left: `${x}px`,
          top: `${y}px`,
        });
      });
    });
  }

  updatePopoverWidth() {
    this.popoverTarget.style.width = `${this.triggerTarget.offsetWidth}px`
  }

  highlightFirstVisibleItem() {
    const visibleInputs = this.visibleInputs()
    this.itemTargets.forEach(item => item.ariaCurrent = "false")

    if (visibleInputs.length === 0 || !this.hasSearchTerm()) {
      this.selectedItemIndex = null
      return
    }

    this.selectedItemIndex = 0
    visibleInputs[0].parentElement.ariaCurrent = "true"
  }

  visibleInputs() {
    return this.inputTargets.filter(input => !input.parentElement.classList.contains("hidden"))
  }

  currentOption() {
    return this.itemTargets.find(item => item.ariaCurrent === "true")
  }

  firstVisibleOption() {
    return this.visibleInputs()[0]?.parentElement
  }

  hasSearchTerm() {
    if (!this.hasSearchInputTarget) { return false }

    return this.searchInputTarget.value.trim().length > 0
  }

  activateOption(option) {
    const input = option?.querySelector("input")
    if (!input) { return }

    if (input.type === "radio") {
      if (!input.checked) {
        input.checked = true
        input.dispatchEvent(new Event("input", { bubbles: true }))
        input.dispatchEvent(new Event("change", { bubbles: true }))
      } else {
        this.updateTriggerContent()
        this.closePopover()
      }
      return
    }

    option.click()
  }

  focusAdjacentElement({ backwards = false } = {}) {
    this.adjacentElement({ backwards })?.focus()
  }

  adjacentElement({ backwards = false } = {}) {
    const focusables = this.focusableElements()
    const currentIndex = focusables.indexOf(this.triggerTarget)
    if (currentIndex === -1) { return null }

    const nextIndex = backwards ? currentIndex - 1 : currentIndex + 1
    return focusables[nextIndex] || null
  }

  focusableElements() {
    const selector = [
      "a[href]",
      "button:not([disabled])",
      "input:not([disabled]):not([type='hidden'])",
      "select:not([disabled])",
      "textarea:not([disabled])",
      "[tabindex]:not([tabindex='-1'])"
    ].join(", ")

    return Array.from(document.querySelectorAll(selector))
      .filter(element => !this.popoverTarget.contains(element))
      .filter(element => this.isVisible(element))
  }

  isVisible(element) {
    return !!(element.offsetWidth || element.offsetHeight || element.getClientRects().length)
  }

  initializeOrderTracking() {
    this.selectedOrder = []
    this.originalActualItems = this.actualItemTargets()
    this.actualItemMap = new Map(
      this.originalActualItems
        .map(item => {
          const input = this.checkboxInput(item)
          return input ? [input.value, item] : null
        })
        .filter(Boolean)
    )

    if (this.reorderValue) {
      this.selectedOrder = this.actualInputs().filter(input => input.checked).map(input => input.value)
      this.reorderItems()
    }
  }

  actualItemTargets() {
    return this.itemTargets.filter(item => {
      const input = this.checkboxInput(item)
      return input && input.name && !input.name.includes("_toggle_all")
    })
  }

  actualInputs() {
    return this.actualItemTargets().map(item => this.checkboxInput(item)).filter(Boolean)
  }

  checkboxInput(item) {
    return item.querySelector("input[type='checkbox']")
  }

  isActualInput(input) {
    return input.name && !input.name.includes("_toggle_all")
  }

  updateSelectedOrder(input) {
    const value = input.value
    this.selectedOrder = this.selectedOrder.filter(v => v !== value)
    if (input.checked) {
      this.selectedOrder.push(value)
    }
  }

  reorderItems() {
    if (!this.reorderValue) { return }
    const actualItems = this.actualItemTargets()
    if (actualItems.length === 0) { return }
    const list = actualItems[0].parentElement
    if (!list) { return }

    const selectedItems = this.selectedOrder.map(value => this.actualItemMap.get(value)).filter(Boolean)
    const remaining = this.originalActualItems.filter(item => !selectedItems.includes(item))

    selectedItems.forEach(item => list.appendChild(item))
    remaining.forEach(item => list.appendChild(item))
  }
}
