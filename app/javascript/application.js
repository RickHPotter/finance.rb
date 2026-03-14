import "@hotwired/turbo-rails"
import { Turbo } from "@hotwired/turbo-rails"
import "./controllers"
import "flowbite/dist/flowbite.turbo.js"

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

let mobileScrollNavCleanup = null

function setupMobileScrollNav() {
  mobileScrollNavCleanup?.()

  const topButton = document.querySelector("[data-mobile-scroll-nav='top']")
  const bottomButton = document.querySelector("[data-mobile-scroll-nav='bottom']")

  if (!topButton || !bottomButton) return

  const scrollingElement = document.scrollingElement || document.documentElement
  let lastScrollY = window.scrollY || scrollingElement.scrollTop || 0
  let lastTouchY = null
  let hideTimer = null

  const dispatchKey = (key) => {
    document.dispatchEvent(new KeyboardEvent("keyup", { key, bubbles: true }))
  }

  const show = (element) => {
    element.style.visibility = "visible"
    element.classList.remove("opacity-0", "translate-y-2", "pointer-events-none")
  }

  const hide = (element) => {
    element.style.visibility = "hidden"
    element.classList.add("opacity-0", "translate-y-2", "pointer-events-none")
  }

  const hideBoth = () => {
    hide(topButton)
    hide(bottomButton)
  }

  const currentScrollPosition = () => window.scrollY || scrollingElement.scrollTop || document.documentElement.scrollTop || document.body.scrollTop || 0
  const nearTop = () => currentScrollPosition() < 40
  const nearBottom = () => {
    const currentScrollY = currentScrollPosition()
    const scrollHeight = Math.max(document.body.scrollHeight, document.documentElement.scrollHeight)
    return window.innerHeight + currentScrollY >= scrollHeight - 120
  }

  const scheduleHide = () => {
    clearTimeout(hideTimer)
    hideTimer = setTimeout(hideBoth, 900)
  }

  const onScroll = () => {
    const currentScrollY = currentScrollPosition()
    const delta = currentScrollY - lastScrollY
    lastScrollY = currentScrollY

    if (Math.abs(delta) < 2) return

    handleDirection(delta, currentScrollY)
  }

  const handleDirection = (delta, currentScrollY = currentScrollPosition()) => {
    if (Math.abs(delta) < 2) return

    if (delta > 0 && !nearBottom()) {
      show(bottomButton)
      hide(topButton)
      scheduleHide()
      return
    }

    if (delta < 0 && Math.max(currentScrollY, lastScrollY) > 80) {
      show(topButton)
      hide(bottomButton)
      scheduleHide()
      return
    }

    hideBoth()
  }

  const onWheel = (event) => {
    handleDirection(event.deltaY)
  }

  const onTouchStart = (event) => {
    lastTouchY = event.touches[0]?.clientY ?? null
  }

  const onTouchMove = (event) => {
    const currentTouchY = event.touches[0]?.clientY
    if (currentTouchY == null || lastTouchY == null) return

    const delta = lastTouchY - currentTouchY
    lastTouchY = currentTouchY
    handleDirection(delta)
  }

  const onTopClick = (event) => {
    event.preventDefault()
    dispatchKey("t")
  }

  const onBottomClick = (event) => {
    event.preventDefault()
    dispatchKey("n")
  }

  hideBoth()

  window.addEventListener("scroll", onScroll, { passive: true })
  document.addEventListener("scroll", onScroll, { passive: true, capture: true })
  window.addEventListener("wheel", onWheel, { passive: true })
  window.addEventListener("touchstart", onTouchStart, { passive: true })
  window.addEventListener("touchmove", onTouchMove, { passive: true })
  topButton.addEventListener("click", onTopClick)
  bottomButton.addEventListener("click", onBottomClick)

  mobileScrollNavCleanup = () => {
    clearTimeout(hideTimer)
    window.removeEventListener("scroll", onScroll)
    document.removeEventListener("scroll", onScroll, { capture: true })
    window.removeEventListener("wheel", onWheel)
    window.removeEventListener("touchstart", onTouchStart)
    window.removeEventListener("touchmove", onTouchMove)
    topButton.removeEventListener("click", onTopClick)
    bottomButton.removeEventListener("click", onBottomClick)
  }
}

document.addEventListener("turbo:load", () => requestAnimationFrame(setupMobileScrollNav))
document.addEventListener("turbo:render", () => requestAnimationFrame(setupMobileScrollNav))
document.addEventListener("turbo:frame-load", () => requestAnimationFrame(setupMobileScrollNav))
