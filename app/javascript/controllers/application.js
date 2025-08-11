import { Application } from "@hotwired/stimulus"

const application = Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus = application

import HwComboboxController from "@josefarias/hotwire_combobox"
application.register("hw-combobox", HwComboboxController)

export { application }

document.addEventListener("click", (event) => {
  const link = event.target.closest("a")

  if (
    link &&
    (event.ctrlKey || event.metaKey) &&
    link.href.includes(".turbo_stream")
  ) {
    event.preventDefault()
    link.click()
  }
})

document.addEventListener("DOMContentLoaded", () => {
  const validStandalonePaths = ["/", "/sidekiq", "/up", "/users", "/lalas"]
  const fullPath = window.location.pathname + window.location.search + window.location.hash

  if (!validStandalonePaths.includes(window.location.pathname)) {
    Turbo.visit("/")

    document.addEventListener("turbo:load", () => {
      console.info("you have been turbo hijacked")
      const centerFrame = document.getElementById("center_container")

      if (centerFrame) {
        const url = new URL(fullPath, window.location.origin)
        if (!url.searchParams.has("format")) {
          url.searchParams.set("format", "turbo_stream")
        }

        centerFrame.src = url.pathname + url.search + url.hash
      }
    })
  }
})

document.addEventListener("keyup", (e) => {
  const tag = document.activeElement && document.activeElement.tagName
  const key = e.key.toLowerCase()
  const inInput = ["INPUT", "TEXTAREA"].includes(tag) || document.activeElement?.isContentEditable
  if (inInput) {
    if (key === "escape") document.activeElement.blur()
    return
  }

  // FOCUS ON SEARCH BAR
  if (key === "f") {
    e.preventDefault()
    document.getElementById("search_term")?.focus()
    return
  }

  // SCROLL TO LAST PAID
  if (key === "n") {
    e.preventDefault()
    const paidTransactions = document.querySelectorAll("[data-datatable-target='row']:not(.animate-pulse)")
    const lastPaidTransaction = paidTransactions[paidTransactions.length - 1]

    lastPaidTransaction.scrollIntoView({ behavior: "smooth", block: "center" })
    lastPaidTransaction.querySelector(".cash_transaction_description").classList.add("animate-bounce")
    setTimeout(() => lastPaidTransaction.querySelector(".cash_transaction_description").classList.remove("animate-bounce"), 3000)
    return
  }

  // SET THEME
  if (key === "t") {
    e.preventDefault()
    document.getElementById("theme_toggle")?.click()
    return
  }

  // PERFORM SCROLL
  if (key !== "j" && key !== "k") return

  const distance = key === "j" ? 150 : -150

  e.preventDefault()
  document.querySelector("body").scrollBy({ top: distance, left: 0, behavior: "smooth" })
})

document.addEventListener("keydown", (e) => {
  const tag = document.activeElement && document.activeElement.tagName
  const key = e.key.toLowerCase()
  const inInput = ["INPUT", "TEXTAREA"].includes(tag) || document.activeElement?.isContentEditable
  if (inInput) {
    if (key === "escape") document.activeElement.blur()
    return
  }

  // PERFORM CONTINUOUS SCROLL
  if (key === "j" || key === "k") {
    const distance = key === "j" ? 500 : -500
    document.querySelector("body").scrollBy({ top: distance, left: 0, behavior: "smooth" })
  }
})
