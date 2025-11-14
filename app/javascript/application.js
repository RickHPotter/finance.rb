import "@hotwired/turbo-rails"
import { Turbo } from "@hotwired/turbo-rails"
import "./controllers"
import "flowbite/dist/flowbite.turbo.js"
import "chartkick/chart.js"

let busyCount = 0
let observedFrames = new WeakSet()

function updateProgressBar() {
  const pb = Turbo.navigator.delegate.adapter.progressBar

  if (busyCount > 0) {
    pb.show()
  } else {
    setTimeout(() => {
      if (busyCount === 0) pb.hide()
    }, 80)
  }
}

function frameBecameBusy() {
  busyCount++
  updateProgressBar()
}

function frameBecameIdle() {
  busyCount = Math.max(0, busyCount - 1)
  updateProgressBar()
}

function observeBusyAttribute(frame) {
  if (!frame || observedFrames.has(frame)) return

  const isInitiallyBusy = frame.hasAttribute("busy")
  if (isInitiallyBusy) frameBecameBusy()

  const observer = new MutationObserver(() => {
    if (frame.hasAttribute("busy")) {
      frameBecameBusy()
    } else {
      frameBecameIdle()
    }
  })

  observer.observe(frame, {
    attributes: true,
    attributeFilter: ["busy"]
  })

  observedFrames.add(frame)
}

function scanForFrames() {
  const frames = document.querySelectorAll("turbo-frame")
  frames.forEach(observeBusyAttribute)
}

const domObserver = new MutationObserver((mutations) => {
  for (const mutation of mutations) {
    mutation.addedNodes.forEach(node => {
      if (node.tagName === "TURBO-FRAME") {
        observeBusyAttribute(node)
      }

      if (node.querySelectorAll) {
        node.querySelectorAll("turbo-frame").forEach(observeBusyAttribute)
      }
    })
  }
})

domObserver.observe(document.documentElement, {
  childList: true,
  subtree: true
})

document.addEventListener("turbo:load", scanForFrames)
document.addEventListener("turbo:frame-load", scanForFrames)
document.addEventListener("turbo:before-stream-render", scanForFrames)
