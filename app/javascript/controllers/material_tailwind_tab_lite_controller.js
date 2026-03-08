import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="material-tailwind-tab-lite"
export default class extends Controller {
  static targets = ["tabList", "tabLink"]

  connect() {
    this.initialise()
    this.syncPanels()
    this.restoreParentLinks()
    this.syncSelectedParentLinks()
    this.fadeInSelectedLinks()

    const loadOnEmptyContent = this.element.dataset.loadOnEmptyContent
    const emptyContent = document.getElementById(loadOnEmptyContent)

    if (!loadOnEmptyContent) { return }
    if (emptyContent?.children?.length) { return }

    this.renderDefault()
  }

  initialise() {
    this.tabListTargets.forEach((tab) => {
      const panel = tab.parentElement
      if (!panel) { return }

      if (tab.dataset.default === "false") {
        panel.classList.add("hidden")
      } else {
        panel.classList.remove("hidden")
      }
    })
  }

  syncPanels() {
    const tabContents = document.querySelectorAll("[data-tab-content]")

    tabContents.forEach((tabContent) => {
      const links = tabContent.previousElementSibling?.querySelectorAll("li a[data-material-tailwind-tab-lite-target=tabLink]") || []
      const activeLink = Array.from(links).find((link) => link.getAttribute("aria-selected") === "true") || links[0]
      if (!activeLink) { return }

      Array.from(tabContent.children).forEach((panel) => {
        panel.classList.add("hidden", "opacity-0")
        panel.classList.remove("block", "opacity-100")
      })

      const activePanel = document.getElementById(activeLink.getAttribute("aria-controls"))
      if (!activePanel) { return }

      activePanel.classList.remove("hidden", "opacity-0")
      activePanel.classList.add("block", "opacity-100")
    })
  }

  renderDefault() {
    this.tabLinkTargets
      .filter((link) => link.getAttribute("aria-selected") === "true")
      .forEach((link) => link.click())
  }

  fadeInSelectedLinks() {
    this.tabLinkTargets
      .filter((link) => link.getAttribute("aria-selected") === "true")
      .forEach((link) => {
        link.classList.add("opacity-0")

        requestAnimationFrame(() => {
          link.classList.remove("opacity-0")
          link.classList.add("opacity-100")
        })
      })
  }

  updateParentLink({ target }) {
    const parentId = target.dataset.parentId
    const parent = this.findParentLink(parentId)
    if (!parent) { return }

    parent.href = target.href
    this.saveParentLink(parentId, target.href)
  }

  syncSelectedParentLinks() {
    this.tabLinkTargets
      .filter((link) => link.dataset.parentId && link.getAttribute("aria-selected") === "true")
      .forEach((link) => this.updateParentLink({ target: link }))
  }

  findParentLink(parentId) {
    return this.tabLinkTargets.find((link) => link.dataset.id === parentId && !link.dataset.parentId)
  }

  restoreParentLinks() {
    this.tabLinkTargets
      .filter((link) => !link.dataset.parentId)
      .forEach((parent) => {
        const savedHref = this.loadParentLink(parent.dataset.id)
        if (!savedHref) { return }

        const hasMatchingChild = this.tabLinkTargets.some((link) => link.dataset.parentId === parent.dataset.id && link.href === savedHref)
        if (!hasMatchingChild) { return }

        parent.href = savedHref
      })
  }

  saveParentLink(parentId, href) {
    if (!parentId || !href) { return }
    window.sessionStorage.setItem(this.storageKey(parentId), href)
  }

  loadParentLink(parentId) {
    if (!parentId) { return null }
    return window.sessionStorage.getItem(this.storageKey(parentId))
  }

  storageKey(parentId) {
    return `tabs:parent-link:${parentId}`
  }
}
