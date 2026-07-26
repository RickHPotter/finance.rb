import { Application } from "@hotwired/stimulus"

const application = Application.start()

application.debug = false
window.Stimulus = application

export { application }

document.addEventListener("turbo:frame-render", (event) => {
  if (event.target.id === "center_container") {
    document.querySelector("#tabs").scrollIntoView({ behavior: "smooth", block: "center" })
  }
})

document.addEventListener("keyup", (e) => {
  if (!e.key) { return }

  const tag = document.activeElement && document.activeElement.tagName
  const key = e.key.toLowerCase()
  const inInput = ["INPUT", "TEXTAREA"].includes(tag) || document.activeElement?.isContentEditable
  if (inInput) {
    if (key === "escape" && !window.__reactiveFormQuickJumpActive) document.activeElement.blur()
    return
  }

  // FOCUS ON SEARCH BAR
  if (key === "f") {
    e.preventDefault()
    document.getElementById("search_term")?.focus()
    return
  }

  if (key === "t") {
    e.preventDefault()
    document.getElementById("theme_toggle")?.click()
    return
  }

  if (key === "p") {
    e.preventDefault()
    document.querySelector("#tabs").scrollIntoView({ behavior: "smooth", block: "center" })

    return
  }

  // SCROLL TO LAST PAID
  if (key === "n") {
    e.preventDefault()
    const paidTransactions = document.querySelectorAll("[data-datatable-target='row']:not(.animate-pulse):not([data-row-kind='budget'])")
    const lastPaidTransaction = paidTransactions[paidTransactions.length - 1]

    if (!lastPaidTransaction) { return }

    const description = lastPaidTransaction.querySelector(".cash_transaction_description")

    lastPaidTransaction.scrollIntoView({ behavior: "smooth", block: "center" })
    description?.classList.add("animate-bounce")
    setTimeout(() => description?.classList.remove("animate-bounce"), 3000)
    return
  }

  // SELECT ALL
  if (key === "s") {
    const selectAllControl = findVisibleSelectAllControl()
    if (!selectAllControl) { return }

    e.preventDefault()
    selectAllControl.click()
    return
  }

  // PERFORM SCROLL
  if (key !== "j" && key !== "k") return

  const distance = key === "j" ? 150 : -150

  e.preventDefault()
  document.querySelector("body").scrollBy({ top: distance, left: 0, behavior: "smooth" })
})

document.addEventListener("keydown", (e) => {
  if (!e.key) { return }

  const tag = document.activeElement && document.activeElement.tagName
  const key = e.key.toLowerCase()
  const inInput = ["INPUT", "TEXTAREA"].includes(tag) || document.activeElement?.isContentEditable
  if (inInput) {
    if (key === "escape" && !window.__reactiveFormQuickJumpActive) document.activeElement.blur()
    return
  }

  // PERFORM CONTINUOUS SCROLL
  if (key === "j" || key === "k") {
    const distance = key === "j" ? 500 : -500
    document.querySelector("body").scrollBy({ top: distance, left: 0, behavior: "smooth" })
  }

})

function findVisibleSelectAllControl() {
  const textMatches = ["select all", "selecionar todos"]
  const valueMatches = ["all", "todos os", "todas as"]

  const candidates = Array.from(document.querySelectorAll("button, [role='button'], input[type='checkbox'], input[type='button'], input[type='submit']"))

  return candidates.find((element) => {
    if (!element.checkVisibility || !element.checkVisibility()) { return false }
    if (element.disabled) { return false }

    const name = (element.getAttribute("name") || "").toLowerCase()
    const text = (element.textContent || "").trim().toLowerCase()
    const value = (element.getAttribute("value") || "").trim().toLowerCase()

    return name.endsWith("_toggle_all") ||
      textMatches.includes(text) ||
      valueMatches.includes(value)
  })
}

const registerServiceWorker = async () => {
  if (navigator.serviceWorker) {
    try {
      await navigator.serviceWorker.register("/serviceworker.js")
      console.info("%c Service worker registered!", "color: green")
    } catch (error) {
      console.error("Error registering service worker: ", error)
    }
  }
}

registerServiceWorker()
