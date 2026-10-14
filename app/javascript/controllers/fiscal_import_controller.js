import { Controller } from "@hotwired/stimulus"
import { _applyMask, _removeMask } from "../utils/mask.js"
import jsQR from "jsqr"

export default class extends Controller {
  static targets = ["file", "source", "button", "status", "cameraPanel", "video"]
  static values = { url: String, reviewMessage: String, replaceMessage: String }

  disconnect() {
    this.stopCamera()
  }

  async startCamera() {
    if (this.cameraOpening || this.cameraStream) return

    if (!navigator.mediaDevices?.getUserMedia) {
      this.showStatus("Live camera scanning needs HTTPS or localhost. Upload a receipt photo instead.", true)
      return
    }

    this.cameraOpening = true
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        audio: false,
        video: { facingMode: { ideal: "environment" }, width: { ideal: 1280 }, height: { ideal: 720 } }
      })
      if (!this.element.isConnected) {
        stream.getTracks().forEach(track => track.stop())
        return
      }

      this.cameraStream = stream
      this.cameraPanelTarget.hidden = false
      this.cameraPanelTarget.classList.remove("hidden")
      this.videoTarget.srcObject = this.cameraStream
      await this.videoTarget.play()
      this.showStatus("Point the camera at the cupom QR code.")
      this.scanCameraFrame()
    } catch (error) {
      this.stopCamera()
      const message = error.name === "NotAllowedError"
        ? "Camera access was denied. Allow camera access or upload a receipt photo."
        : "Could not open the camera. Upload a receipt photo instead."
      this.showStatus(message, true)
    } finally {
      this.cameraOpening = false
    }
  }

  stopCamera() {
    if (this.cameraFrame) cancelAnimationFrame(this.cameraFrame)
    this.cameraFrame = null
    this.cameraStream?.getTracks().forEach(track => track.stop())
    this.cameraStream = null
    if (this.hasVideoTarget) this.videoTarget.srcObject = null
    if (this.hasCameraPanelTarget) this.cameraPanelTarget.hidden = true
    if (this.hasCameraPanelTarget) this.cameraPanelTarget.classList.add("hidden")
  }

  async scanCameraFrame() {
    if (!this.cameraStream) return

    const video = this.videoTarget
    if (video.readyState >= HTMLMediaElement.HAVE_CURRENT_DATA) {
      const scale = Math.min(1, 1600 / Math.max(video.videoWidth, video.videoHeight))
      const canvas = this.cameraCanvas || (this.cameraCanvas = document.createElement("canvas"))
      canvas.width = Math.max(1, Math.round(video.videoWidth * scale))
      canvas.height = Math.max(1, Math.round(video.videoHeight * scale))
      const context = canvas.getContext("2d", { willReadFrequently: true })
      context.drawImage(video, 0, 0, canvas.width, canvas.height)
      const pixels = context.getImageData(0, 0, canvas.width, canvas.height)
      const source = jsQR(pixels.data, pixels.width, pixels.height, { inversionAttempts: "attemptBoth" })?.data
      if (source) {
        const blob = await new Promise(resolve => canvas.toBlob(resolve, "image/jpeg", 0.9))
        const file = blob ? new File([blob], "fiscal-receipt-camera.jpg", { type: "image/jpeg", lastModified: Date.now() }) : null
        this.stopCamera()
        this.showStatus("QR found. Retrieving fiscal items...")
        this.performImport({ source, file })
        return
      }
    }

    this.cameraFrame = requestAnimationFrame(() => this.scanCameraFrame())
  }

  async importFile() {
    const file = this.fileTarget.files[0]
    if (!file) {
      this.showStatus("Choose a fiscal XML, PDF, or image first.", true)
      return
    }

    if (file.size > 10 * 1024 * 1024) {
      this.showStatus("The fiscal file must be 10 MB or smaller.", true)
      return
    }

    if (file.type.startsWith("image/") || /\.(jpe?g|png|heic)$/i.test(file.name)) {
      try {
        this.showStatus("Reading the receipt QR code...")
        const source = await this.readImageQr(file)
        if (!source) throw new Error("No readable QR code was found in this image. Try live camera scan, XML, PDF, or a supported key.")
        await this.performImport({ file, source })
      } catch (error) {
        this.showStatus(error.message, true)
      }
      return
    }

    this.performImport({ file })
  }

  lookup() {
    const source = this.sourceTarget.value.trim()
    if (!source) {
      this.showStatus("Enter a supported 44-digit key or Paraná/Goiás QR URL first.", true)
      return
    }

    this.performImport({ source })
  }

  async performImport({ file, source }) {
    this.buttonTargets.forEach(button => { button.disabled = true })
    this.showStatus("Reading fiscal items...")

    try {
      const body = new FormData()
      if (source) body.append("source", source)
      else if (file) body.append("file", file)
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: { "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content || "", Accept: "application/json" },
        body
      })
      const result = await response.json()
      if (!response.ok) throw new Error(result.error || "The receipt could not be imported.")
      if (this.hasExistingValues() && !window.confirm(this.replaceMessageValue)) return

      this.applyDraft(result.draft)
      if (file) this.stageAttachment(file)
      this.showStatus(this.reviewMessageValue.replace("%{count}", result.draft.items.length))
    } catch (error) {
      this.showStatus(error.message, true)
    } finally {
      this.buttonTargets.forEach(button => { button.disabled = false })
    }
  }

  hasExistingValues() {
    const description = this.parentDescriptionInput()?.value.trim()
    const price = _removeMask(this.parentPriceInput()?.value || "")
    const lineDescription = this.element.querySelector("[data-composite-transaction-target~='row'] input[name$='[description]']")?.value.trim()
    return Boolean(description || (price && parseInt(price, 10) !== 0) || lineDescription)
  }

  applyDraft(draft) {
    const splitTab = this.element.querySelector("[data-value='split']")
    const composite = this.application.getControllerForElementAndIdentifier(this.element, "composite-transaction")
    const priceMask = this.application.getControllerForElementAndIdentifier(this.element, "price-mask")
    if (!splitTab || splitTab.disabled || !composite || !priceMask) throw new Error("The split purchase form is unavailable.")

    splitTab.click()
    composite.clearAllRows()
    priceMask.setSignForSelector(".sign-based", "-")

    const description = this.parentDescriptionInput()
    if (description) description.value = draft.issuer || "Cupom fiscal"
    const parentPrice = this.parentPriceInput()
    parentPrice.value = _applyMask((-draft.total_cents).toString())
    parentPrice.dispatchEvent(new Event("input", { bubbles: true }))

    draft.items.forEach((item) => {
      composite.addRow()
      const row = composite.activeRows.at(-1)
      row.querySelector("input[name$='[description]']").value = item.description
      const price = row.querySelector("[data-composite-transaction-target~='itemPrice']")
      price.value = _applyMask((-item.price_cents).toString())
      price.dispatchEvent(new Event("input", { bubbles: true }))
    })
    composite.recalculate()
  }

  stageAttachment(file) {
    const signature = `${file.name}:${file.size}:${file.lastModified}`
    if (signature === this.lastStagedFile) return

    const upload = this.application.getControllerForElementAndIdentifier(this.element, "attachment-upload")
    upload?.processFiles([file])
    this.lastStagedFile = signature
  }

  async readImageQr(file) {
    const bitmap = await createImageBitmap(file)
    try {
      if (bitmap.width * bitmap.height > 25_000_000) throw new Error("The receipt image has too many pixels to scan safely.")

      const scale = Math.min(1, 1600 / Math.max(bitmap.width, bitmap.height))
      const canvas = document.createElement("canvas")
      canvas.width = Math.max(1, Math.round(bitmap.width * scale))
      canvas.height = Math.max(1, Math.round(bitmap.height * scale))
      const context = canvas.getContext("2d", { willReadFrequently: true })
      context.drawImage(bitmap, 0, 0, canvas.width, canvas.height)
      const pixels = context.getImageData(0, 0, canvas.width, canvas.height)
      return jsQR(pixels.data, pixels.width, pixels.height, { inversionAttempts: "attemptBoth" })?.data
    } finally {
      bitmap.close()
    }
  }

  parentDescriptionInput() {
    return this.element.querySelector("input[name$='[description]']:not([name*='[line_items_attributes]'])")
  }

  parentPriceInput() {
    return this.element.querySelector("#transaction_price")
  }

  showStatus(message, error = false) {
    this.statusTarget.textContent = message
    this.statusTarget.classList.toggle("text-rose-600", error)
    this.statusTarget.classList.toggle("text-emerald-700", !error)
  }
}
