import { Controller } from "@hotwired/stimulus"
import { fetchReportJson, formatReportCurrency, observeReportVisibility, showReportState } from "../lib/report_presentation.mjs"

export default class extends Controller {
  static values = {
    url: String,
    locale: String,
    currency: String,
    labels: Object
  }

  static targets = [
    "loadingState",
    "errorState",
    "errorMessage",
    "content",
    "definition",
    "actual",
    "remaining",
    "utilization",
    "periodCompletion",
    "status",
    "utilizationBar",
    "utilizationProgress",
    "periodCompletionBar",
    "periodCompletionProgress",
    "rules",
    "sources"
  ]

  connect() {
    this.requestSequence = 0
    this.observeVisibility()
  }

  disconnect() {
    this.visibilityObserver?.disconnect()
    this.abortController?.abort()
  }

  retry() {
    this.load()
  }

  observeVisibility() {
    this.visibilityObserver = observeReportVisibility(this.element, () => this.load())
  }

  async load() {
    const sequence = ++this.requestSequence
    this.abortController?.abort()
    this.abortController = new AbortController()
    this.showLoading()

    try {
      const payload = await fetchReportJson(this.urlValue, this.abortController.signal, this.label("error"))
      if (sequence !== this.requestSequence) return

      this.renderPayload(payload)
      this.showContent()
    } catch (error) {
      if (error.name === "AbortError" || sequence !== this.requestSequence) return

      this.showError(error.message)
    }
  }

  renderPayload(payload) {
    const performance = payload.performance
    this.definitionTarget.textContent = this.formatCents(payload.definition.amount_cents)
    this.actualTarget.textContent = this.formatCents(performance.actual_cents)
    this.remainingTarget.textContent = this.formatCents(performance.remaining_cents)
    this.utilizationTarget.textContent = this.formatPercentage(performance.utilization_percentage)
    this.periodCompletionTarget.textContent = this.formatPercentage(performance.period_completion_percentage)
    this.statusTarget.textContent = this.label(performance.status)
    this.renderStatus(performance.status)
    this.renderProgress(this.utilizationBarTarget, this.utilizationProgressTarget, performance.utilization_percentage)
    this.renderProgress(this.periodCompletionBarTarget, this.periodCompletionProgressTarget, performance.period_completion_percentage)
    this.renderRules(payload)
    this.renderSources(payload.sources)
  }

  renderProgress(bar, progress, percentage) {
    const value = Number(percentage) || 0
    bar.style.width = `${Math.min(Math.max(value, 0), 100)}%`
    bar.classList.toggle("bg-rose-600", value > 100)
    bar.classList.toggle("bg-sky-600", value <= 100)
    progress.setAttribute("aria-valuenow", String(value))
    progress.setAttribute("aria-valuemax", String(Math.max(100, value)))
  }

  renderStatus(status) {
    this.statusTarget.classList.toggle("text-rose-700", status === "exceeded")
    this.statusTarget.classList.toggle("dark:text-rose-300", status === "exceeded")
    this.statusTarget.classList.toggle("text-amber-700", status === "exact")
    this.statusTarget.classList.toggle("dark:text-amber-300", status === "exact")
    this.statusTarget.classList.toggle("text-emerald-700", status === "available")
    this.statusTarget.classList.toggle("dark:text-emerald-300", status === "available")
  }

  renderRules(payload) {
    this.rulesTarget.replaceChildren(
      this.ruleCard(this.label(`inclusive_${payload.rules.inclusive}`)),
      this.ruleCard(this.label(`first_installment_only_${payload.rules.first_installment_only}`)),
      this.ruleCard(this.label("current_limit"), this.formatCents(payload.definition.current_limit_cents)),
      this.ruleCard(this.label("recorded_remaining"), this.formatCents(payload.definition.recorded_remaining_cents))
    )
  }

  ruleCard(label, value = null) {
    const card = document.createElement("div")
    card.className = "rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm text-slate-700 dark:border-slate-700 dark:bg-slate-900 dark:text-slate-200"
    const text = document.createElement("p")
    text.className = "font-semibold"
    text.textContent = label
    card.appendChild(text)

    if (value) {
      const detail = document.createElement("p")
      detail.className = "mt-1 text-xs text-slate-500 dark:text-slate-400"
      detail.textContent = value
      card.appendChild(detail)
    }

    return card
  }

  renderSources(sources) {
    this.sourcesTarget.replaceChildren()
    ;["cash", "card"].forEach((type) => this.sourcesTarget.appendChild(this.sourceCard(type, sources[type])))
  }

  sourceCard(type, source) {
    const card = document.createElement("div")
    card.className = "rounded-2xl border border-slate-200 bg-white p-3 dark:border-slate-700 dark:bg-slate-900"
    const header = document.createElement("div")
    header.className = "flex items-center justify-between gap-3"
    const title = document.createElement("p")
    title.className = "text-sm font-bold text-slate-950 dark:text-slate-100"
    title.textContent = this.label(type)
    const amount = document.createElement("p")
    amount.className = "text-sm font-bold text-slate-950 dark:text-slate-100"
    amount.textContent = this.formatCents(source.amount_cents)
    header.append(title, amount)
    card.appendChild(header)

    const links = document.createElement("div")
    links.className = "mt-3 flex flex-wrap gap-2"
    if (!source.chunks.length) {
      const empty = document.createElement("span")
      empty.className = "text-xs text-slate-400 dark:text-slate-500"
      empty.textContent = this.label("no_sources")
      links.appendChild(empty)
    } else {
      source.chunks.forEach((chunk, index) => links.appendChild(this.sourceLink(type, chunk, index, source.chunks.length)))
    }
    card.appendChild(links)
    return card
  }

  sourceLink(type, chunk, index, totalChunks) {
    const link = document.createElement("a")
    link.href = chunk.path
    link.className = "rounded-lg border border-sky-200 bg-sky-50 px-2 py-1 text-xs font-semibold text-sky-800 hover:bg-sky-100 " +
      "dark:border-sky-900 dark:bg-sky-950/40 dark:text-sky-300 dark:hover:bg-sky-900/50"
    link.dataset.turboFrame = "_top"
    link.dataset.turboPrefetch = "false"
    const chunkLabel = totalChunks > 1 ? ` ${this.label("chunk")} ${index + 1}/${totalChunks}` : ""
    link.textContent = `${this.label(type)}${chunkLabel} — ${this.formatCents(chunk.amount_cents)} (${chunk.count})`
    return link
  }

  formatCents(value) {
    return formatReportCurrency((Number(value) || 0) / 100, this.localeValue, this.currencyValue)
  }

  formatPercentage(value) {
    return `${new Intl.NumberFormat(this.localeValue, { maximumFractionDigits: 2 }).format(Number(value) || 0)}%`
  }

  showLoading() {
    showReportState(this.element, this.reportStateTargets(), "loading")
  }

  showError(message) {
    this.errorMessageTarget.textContent = message || this.label("error")
    showReportState(this.element, this.reportStateTargets(), "error")
  }

  showContent() {
    showReportState(this.element, this.reportStateTargets(), "content")
  }

  reportStateTargets() {
    return { loading: this.loadingStateTarget, error: this.errorStateTarget, content: this.contentTarget }
  }

  label(key) {
    return this.labelsValue[key] || key
  }
}
