import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    pixelsPerMinute: { type: Number, default: 100 },
    broomActive: { type: Boolean, default: false }
  }

  connect() {
    this.#startSnow()
  }

  disconnect() {
    this.#stopSnow()
    this.#meltSnow()
  }

  trackMouse(event) {
    const { clientX, clientY, buttons } = event

    if (buttons === 1) {
      this.broomActiveValue = true

      this.#sweepAtPosition(clientX, clientY)
    } else {
      this.broomActiveValue = false
    }
  }

  sweepAwaySnow({ clientX, clientY }) {
    if (!this.broomActiveValue) return

    this.#sweepAtPosition(clientX, clientY)
  }

  // Private

  #fallingSnow = []
  #piledSnow = []
  #animationFrame = null
  #accumulatedHeight = 0

  #intensityMap = {
    flurry: 60,
    light: 200,
    steady: 500,
    heavy: 1000,
    blizzard: 2000
  }

  intensityValueChanged(newIntensity) {
    if (this.#intensityMap[newIntensity]) {
      this.pixelsPerMinuteValue = this.#intensityMap[newIntensity]
    }
  }

  broomActiveValueChanged(isBrooming) {
    document.body.style.cursor = isBrooming
      ? "url('data:image/svg+xml;utf8,<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"32\" height=\"32\" viewBox=\"0 0 32 32\"><text y=\"28\" font-size=\"28\">🧹</text></svg>') 0 32, auto"
      : "default"
  }

  #startSnow() {
    this.#animationFrame = requestAnimationFrame(() => this.#animate())
  }

  #stopSnow() {
    if (this.#animationFrame) {
      cancelAnimationFrame(this.#animationFrame)

      this.#animationFrame = null
    }
  }

  #animate() {
    this.#createSnowBasedOnIntensity()
    this.#updateFallingSnow()
    this.#settleSnowAtBottom()

    this.#animationFrame = requestAnimationFrame(() => this.#animate())
  }

  #createSnowBasedOnIntensity() {
    const probability = Math.min(0.5, (this.pixelsPerMinuteValue / 1000) * 0.3)

    if (Math.random() < probability) this.#createSnowflake()
  }

  #createSnowflake() {
    const snowflake = document.createElement("div")

    snowflake.textContent = "❄️"
    this.#applySnowflakeStyles(snowflake)
    this.#applySnowflakePhysics(snowflake)

    document.body.appendChild(snowflake)

    this.#fallingSnow.push(snowflake)
  }

  #applySnowflakeStyles(snowflake) {
    Object.assign(snowflake.style, {
      position: "fixed",
      left: `${Math.random() * window.innerWidth}px`,
      top: "-50px",
      fontSize: `${Math.random() * 20 + 15}px`,
      pointerEvents: "none",
      zIndex: "9999",
      userSelect: "none",
      isolation: "isolate"
    })
  }

  #applySnowflakePhysics(snowflake) {
    snowflake.dataset.velocityY = (Math.random() * 1 + 0.5).toString()
    snowflake.dataset.velocityX = (Math.random() * 0.5 - 0.25).toString()
    snowflake.dataset.rotation = "0"
    snowflake.dataset.rotationSpeed = (Math.random() * 2 - 1).toString()
  }

  #updateFallingSnow() {
    const bottomThreshold = window.innerHeight - this.#accumulatedHeight

    this.#fallingSnow.forEach(snowflake => {
      this.#moveSnowflake(snowflake)

      if (this.#getSnowflakeTop(snowflake) >= bottomThreshold) {
        snowflake.dataset.settled = "true"
      }
    })
  }

  #moveSnowflake(snowflake) {
    const top = parseFloat(snowflake.style.top)
    const left = parseFloat(snowflake.style.left)
    const velocityY = parseFloat(snowflake.dataset.velocityY)
    const velocityX = parseFloat(snowflake.dataset.velocityX)
    const rotation = parseFloat(snowflake.dataset.rotation)
    const rotationSpeed = parseFloat(snowflake.dataset.rotationSpeed)

    let newLeft = left + velocityX
    newLeft = this.#constrainHorizontally(snowflake, newLeft, velocityX)

    snowflake.style.top = `${top + velocityY}px`
    snowflake.style.left = `${newLeft}px`
    snowflake.style.transform = `rotate(${rotation + rotationSpeed}deg)`
    snowflake.dataset.rotation = (rotation + rotationSpeed).toString()
  }

  #constrainHorizontally(snowflake, left, velocityX) {
    if (left < 0) {
      snowflake.dataset.velocityX = Math.abs(velocityX).toString()

      return 0
    }

    if (left > window.innerWidth) {
      snowflake.dataset.velocityX = (-Math.abs(velocityX)).toString()

      return window.innerWidth
    }

    return left
  }

  #getSnowflakeTop(snowflake) {
    return parseFloat(snowflake.style.top)
  }

  #settleSnowAtBottom() {
    const settledSnow = this.#fallingSnow.filter(s => s.dataset.settled === "true")

    if (settledSnow.length === 0) return

    settledSnow.forEach(snowflake => {
      const finalTop = window.innerHeight - this.#accumulatedHeight - 30

      snowflake.style.top = `${finalTop}px`
      snowflake.dataset.bottomOffset = this.#accumulatedHeight.toString()

      this.#piledSnow.push(snowflake)
    })

    this.#fallingSnow = this.#fallingSnow.filter(s => s.dataset.settled !== "true")

    this.#increaseAccumulatedSnow(settledSnow.length)
  }

  #increaseAccumulatedSnow(count) {
    this.#accumulatedHeight += (count * this.pixelsPerMinuteValue) / 3600
  }

  #sweepAtPosition(mouseX, mouseY) {
    const sweepRadius = 80
    const sweptSnow = this.#findSnowInRadius(mouseX, mouseY, sweepRadius)

    if (sweptSnow.length === 0) return

    sweptSnow.forEach(snowflake => snowflake.remove())
    this.#piledSnow = this.#piledSnow.filter(s => !sweptSnow.includes(s))
    this.#decreaseAccumulatedSnow(sweptSnow.length)
  }

  #findSnowInRadius(mouseX, mouseY, radius) {
    return this.#piledSnow.filter(snowflake => {
      const left = parseFloat(snowflake.style.left)
      const top = parseFloat(snowflake.style.top)
      const distance = Math.sqrt(Math.pow(mouseX - left, 2) + Math.pow(mouseY - top, 2))

      return distance <= radius
    })
  }

  #decreaseAccumulatedSnow(count) {
    const pixelsToRemove = (count * this.pixelsPerMinuteValue) / 3600

    this.#accumulatedHeight = Math.max(0, this.#accumulatedHeight - pixelsToRemove)
  }

  #meltSnow() {
    this.#fallingSnow.forEach(s => s.remove())
    this.#piledSnow.forEach(s => s.remove())
    this.#fallingSnow = []
    this.#piledSnow = []
  }
}
