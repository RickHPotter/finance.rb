import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage"

export default class extends Controller {
  static targets = ["input", "dropzone", "list", "hiddenContainer", "counter"]
  static values = {
    directUploadUrl: { type: String, default: "/rails/active_storage/direct_uploads" },
    modelName: { type: String, default: "cash_transaction" },
    maxFileSize: { type: Number, default: 10485760 },
    maxFiles: { type: Number, default: 5 },
    existingCount: { type: Number, default: 0 },
    tooLargeMessage: { type: String, default: "File is larger than 10 MB." },
    invalidTypeMessage: { type: String, default: "File type is not supported." },
    maxCountMessage: { type: String, default: "Maximum of 5 attachments allowed." },
    uploadingMessage: { type: String, default: "Uploading..." },
    waitForUploadsMessage: { type: String, default: "Please wait for uploads to finish." }
  }

  connect() {
    this.pendingUploads = new Map()
    this.observeRemovedAttachments()
    this.updateCounter()
  }

  disconnect() {
    this.attachmentObserver?.disconnect()
  }

  observeRemovedAttachments() {
    this.attachmentObserver = new MutationObserver((mutations) => {
      mutations.flatMap(mutation => Array.from(mutation.removedNodes)).forEach((node) => {
        if (node.nodeType === Node.ELEMENT_NODE && node.id?.startsWith("attachment_row_") && this.existingCountValue > 0) {
          this.existingCountValue--
          this.updateCounter()
        }
      })
    })
    this.attachmentObserver.observe(this.element, { childList: true, subtree: true })
  }

  handleFiles(event) {
    const files = Array.from(event.target.files)
    this.processFiles(files)
    this.inputTarget.value = ""
  }

  beforeSubmit(event) {
    const uploading = Array.from(this.pendingUploads.values()).some(item => item.state === "uploading")
    if (uploading) {
      event.preventDefault()
      alert(this.waitForUploadsMessageValue)
    }
  }

  dragOver(event) {
    event.preventDefault()
    if (this.hasDropzoneTarget) {
      this.dropzoneTarget.classList.add("border-blue-500", "bg-blue-50/10")
    }
  }

  dragLeave(event) {
    event.preventDefault()
    if (this.hasDropzoneTarget) {
      this.dropzoneTarget.classList.remove("border-blue-500", "bg-blue-50/10")
    }
  }

  drop(event) {
    event.preventDefault()
    if (this.hasDropzoneTarget) {
      this.dropzoneTarget.classList.remove("border-blue-500", "bg-blue-50/10")
    }
    if (event.dataTransfer?.files?.length) {
      this.processFiles(Array.from(event.dataTransfer.files))
    }
  }

  processFiles(files) {
    const allowedMimes = [
      "application/pdf",
      "image/jpeg",
      "image/png",
      "image/heic",
      "application/xml",
      "text/xml",
      "application/zip"
    ]
    const allowedExtensions = [".pdf", ".jpg", ".jpeg", ".png", ".heic", ".xml", ".zip"]

    for (const file of files) {
      const currentTotal = this.existingCountValue + this.pendingUploads.size
      if (currentTotal >= this.maxFilesValue) {
        alert(this.maxCountMessageValue)
        break
      }

      const extension = "." + file.name.split(".").pop().toLowerCase()
      const isAllowed = allowedMimes.includes(file.type) || allowedExtensions.includes(extension)
      if (!isAllowed) {
        alert(`${file.name}: ${this.invalidTypeMessageValue}`)
        continue
      }

      if (file.size > this.maxFileSizeValue) {
        alert(`${file.name}: ${this.tooLargeMessageValue}`)
        continue
      }

      this.startDirectUpload(file)
    }
  }

  startDirectUpload(file) {
    const id = "upload_" + Date.now() + "_" + Math.random().toString(36).substring(2, 9)
    const itemEl = this.createItemElement(id, file)
    this.listTarget.appendChild(itemEl)

    const upload = new DirectUpload(file, this.directUploadUrlValue, {
      directUploadWillStoreFileWithXHR: (request) => {
        request.upload.addEventListener("progress", (event) => {
          const percent = Math.round((event.loaded / event.total) * 100)
          this.updateProgress(id, percent)
        })
      }
    })

    this.pendingUploads.set(id, { file, upload, element: itemEl, hiddenInput: null, state: "uploading" })
    this.updateCounter()

    upload.create((error, blob) => {
      if (error) {
        this.showError(id, error)
      } else {
        this.finishUpload(id, blob)
      }
    })
  }

  createItemElement(id, file) {
    const div = document.createElement("div")
    div.id = id
    div.className = "flex items-center justify-between p-2.5 rounded-lg border border-slate-200 dark:border-slate-700 bg-white/60 dark:bg-slate-800/60 text-sm gap-3"

    const isImage = file.type.startsWith("image/")
    let previewHtml = ""
    if (isImage) {
      const objectUrl = URL.createObjectURL(file)
      previewHtml = `<img src="${objectUrl}" class="w-9 h-9 object-cover rounded border border-slate-200 dark:border-slate-700 shrink-0">`
    } else {
      previewHtml = `<div class="w-9 h-9 rounded border border-slate-200 dark:border-slate-700 bg-slate-100 dark:bg-slate-800 flex items-center justify-center font-mono text-2xs uppercase text-slate-500 shrink-0">${this.escapeHtml(file.name.split(".").pop())}</div>`
    }

    const formattedSize = this.formatBytes(file.size)

    div.innerHTML = `
      <div class="flex items-center gap-3 min-w-0 flex-1">
        ${previewHtml}
        <div class="min-w-0 flex-1">
          <p class="font-medium text-slate-900 dark:text-slate-100 truncate text-xs sm:text-sm">${this.escapeHtml(file.name)}</p>
          <div class="flex items-center gap-2 text-2xs text-slate-500 dark:text-slate-400">
            <span>${formattedSize}</span>
            <span>•</span>
            <span class="status-text">${this.uploadingMessageValue}</span>
          </div>
          <div class="w-full bg-slate-200 dark:bg-slate-700 h-1 rounded-full mt-1 overflow-hidden">
            <div class="progress-bar bg-blue-600 h-full rounded-full transition-all duration-200" style="width: 0%"></div>
          </div>
        </div>
      </div>
      <button type="button" class="remove-btn text-slate-400 hover:text-rose-500 p-1 rounded transition-colors shrink-0" data-id="${id}">
        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18"/><path d="m6 6 12 12"/></svg>
      </button>
    `

    div.querySelector(".remove-btn").addEventListener("click", () => this.removeItem(id))
    return div
  }

  updateProgress(id, percent) {
    const item = this.pendingUploads.get(id)
    if (!item) return

    const bar = item.element.querySelector(".progress-bar")
    if (bar) bar.style.width = `${percent}%`

    const status = item.element.querySelector(".status-text")
    if (status && percent < 100) {
      status.textContent = `${this.uploadingMessageValue} ${percent}%`
    }
  }

  finishUpload(id, blob) {
    const item = this.pendingUploads.get(id)
    if (!item) return
    item.state = "uploaded"

    const hiddenInput = document.createElement("input")
    hiddenInput.type = "hidden"
    hiddenInput.name = `${this.modelNameValue}[receipts][]`
    hiddenInput.value = blob.signed_id
    this.hiddenContainerTarget.appendChild(hiddenInput)
    item.hiddenInput = hiddenInput

    const bar = item.element.querySelector(".progress-bar")
    if (bar) {
      bar.style.width = "100%"
      bar.classList.remove("bg-blue-600")
      bar.classList.add("bg-emerald-500")
    }

    const status = item.element.querySelector(".status-text")
    if (status) {
      status.textContent = "✓"
      status.classList.add("text-emerald-500", "font-semibold")
    }
  }

  showError(id, error) {
    const item = this.pendingUploads.get(id)
    if (!item) return
    item.state = "failed"

    const status = item.element.querySelector(".status-text")
    if (status) {
      status.textContent = error || "Upload failed"
      status.classList.add("text-rose-500")
    }

    const bar = item.element.querySelector(".progress-bar")
    if (bar) {
      bar.classList.remove("bg-blue-600")
      bar.classList.add("bg-rose-500")
    }
  }

  removeItem(id) {
    const item = this.pendingUploads.get(id)
    if (!item) return

    if (item.hiddenInput) {
      item.hiddenInput.remove()
    }
    item.element.remove()
    this.pendingUploads.delete(id)
    this.updateCounter()
  }

  updateCounter() {
    const total = this.existingCountValue + this.pendingUploads.size
    this.counterTargets.forEach(target => {
      if (target.dataset.format === "fraction") {
        target.textContent = `${total} / ${this.maxFilesValue}`
      } else {
        target.textContent = total.toString()
      }
    })
  }

  formatBytes(bytes) {
    if (bytes === 0) return "0 B"
    const k = 1024
    const sizes = ["B", "KB", "MB", "GB"]
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + " " + sizes[i]
  }

  escapeHtml(string) {
    const div = document.createElement("div")
    div.textContent = string
    return div.innerHTML
  }
}
