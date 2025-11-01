import { Application } from "@hotwired/stimulus"

const application = Application.start()

application.debug = false
window.Stimulus = application

import HwComboboxController from "@josefarias/hotwire_combobox"
application.register("hw-combobox", HwComboboxController)

export { application }

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

const registerServiceWorker = async () => {
  if (navigator.serviceWorker) {
    try {
      await navigator.serviceWorker.register("/serviceworker.js")
      console.log("Service worker registered!")
    } catch (error) {
      console.error("Error registering service worker: ", error)
    }
  }
}

registerServiceWorker()

// ============== HISTORY MANAGEMENT ==============

let currentFrameUrl = null
let historyStack = []

function normalizeUrl(urlString) {
  const url = new URL(urlString, window.location.origin)
  url.searchParams.delete("format")
  url.searchParams.delete("authenticity_token")
  return url.pathname + url.search + url.hash
}

function updateHistory(newUrl, action = "push") {
  const normalized = normalizeUrl(newUrl)

  if (currentFrameUrl === normalized) return

  if (action === "push" && currentFrameUrl) {
    historyStack.push(currentFrameUrl)
  }

  currentFrameUrl = normalized

  const historyMethod = action === "push" ? "pushState" : "replaceState"
  window.history[historyMethod](
    {
      turbo_frame_history: true,
      frame_url: normalized
    },
    "",
    normalized
  )
}

document.addEventListener("DOMContentLoaded", () => {
  const otherPaths = ["/up"]
  const otherDomains = ["/lalas"]
  const devisePaths = [
    "/users/sign_in",
    "/users/sign_up",
    "/users/password/new",
    "/users/password/edit",
    "/users/confirmation/new",
    "/users/unlock/new"
  ]

  if (otherPaths.includes(window.location.pathname)) return
  if (otherDomains.find(domain => window.location.pathname.startsWith(domain))) return
  if (devisePaths.includes(window.location.pathname)) return

  const currentPath = window.location.pathname

  if ("/".includes(currentPath)) {
    currentFrameUrl = currentPath
    window.history.replaceState(
      { turbo_frame_history: true, frame_url: currentPath },
      "",
      currentPath
    )
    return
  }

  const fullPath = window.location.pathname + window.location.search + window.location.hash
  currentFrameUrl = fullPath

  document.addEventListener("turbo:load", () => {
    const centerFrame = document.getElementById("center_container")
    if (!centerFrame) return

    const url = new URL(fullPath, window.location.origin)
    if (!url.searchParams.has("format")) {
      url.searchParams.set("format", "turbo_stream")
    }
    centerFrame.src = url.pathname + url.search + url.hash

    centerFrame.addEventListener("turbo:frame-load", () => {
      window.history.replaceState(
        { turbo_frame_history: true, frame_url: currentFrameUrl },
        "",
        currentFrameUrl
      )
    }, { once: true })
  }, { once: true })

  Turbo.visit("/", { action: "replace" })
})

document.addEventListener("turbo:click", (event) => {
  const link = event.target.closest("a")
  if (!link) return

  const targetFrame = link.dataset.turboFrame
  if (targetFrame !== "center_container") return

  updateHistory(link.href, "push")
})

document.addEventListener("turbo:submit-end", (event) => {
  const form = event.target
  const centerFrame = form.closest("turbo-frame#center_container")

  if (!centerFrame || form.method.toLowerCase() !== "get") return

  const formData = new FormData(form)
  const formUrl = new URL(form.action, window.location.origin)

  for (const [key, value] of formData.entries()) {
    if (value && value.trim() !== "") {
      formUrl.searchParams.set(key, value)
    }
  }

  updateHistory(formUrl.toString(), "push")
})

window.addEventListener("popstate", (event) => {
  const centerFrame = document.getElementById("center_container")
  if (!centerFrame) return

  if (event.state?.turbo_frame_history) {
    currentFrameUrl = event.state.frame_url
    if (historyStack.length > 0) {
      historyStack.pop()
    }
  } else {
    currentFrameUrl = window.location.pathname + window.location.search + window.location.hash
  }

  if (currentFrameUrl && currentFrameUrl !== "/") {
    const url = new URL(currentFrameUrl, window.location.origin)
    if (!url.searchParams.has("format")) {
      url.searchParams.set("format", "turbo_stream")
    }
    centerFrame.src = url.pathname + url.search + url.hash
  }
})
