import { Controller } from "@hotwired/stimulus"
import { BarController, BarElement, CategoryScale, Chart, LinearScale, Tooltip } from "chart.js"

Chart.register(BarController, BarElement, CategoryScale, LinearScale, Tooltip)

export default class extends Controller {
  static values = {
    url: String,
    locale: String,
    currency: String,
    labels: Object
  }

  static targets = [
    "fromDate",
    "toDate",
    "granularity",
    "paidState",
    "direction",
    "loadingState",
    "errorState",
    "errorMessage",
    "emptyState",
    "content",
    "summaryIncome",
    "summaryOutcome",
    "summaryNet",
    "chartCanvas",
    "bucketList",
    "breakdownList",
    "paymentStateList",
    "balanceContext",
    "detailList"
  ]

  connect() {
    this.chart = null
    this.payload = null
    this.requestSequence = 0
    this.themeObserver = new MutationObserver(() => this.redrawChart())
    this.themeObserver.observe(document.documentElement, { attributes: true, attributeFilter: ["class"] })
    this.observeVisibility()
  }

  disconnect() {
    this.visibilityObserver?.disconnect()
    this.themeObserver?.disconnect()
    this.abortController?.abort()
    this.destroyChart()
  }

  changeFilters() {
    this.syncNavigationState()
    this.load()
  }

  retry() {
    this.load()
  }

  observeVisibility() {
    if (!("IntersectionObserver" in window)) {
      this.load()
      return
    }

    this.visibilityObserver = new IntersectionObserver((entries) => {
      if (!entries.some((entry) => entry.isIntersecting)) return

      this.visibilityObserver.disconnect()
      this.load()
    }, { rootMargin: "160px" })
    this.visibilityObserver.observe(this.element)
  }

  async load() {
    const sequence = ++this.requestSequence
    this.abortController?.abort()
    this.abortController = new AbortController()
    this.showLoading()

    try {
      const response = await fetch(this.requestUrl(), {
        headers: { Accept: "application/json" },
        signal: this.abortController.signal
      })
      const payload = await response.json()

      if (!response.ok) throw new Error(payload.error || this.label("error"))
      if (sequence !== this.requestSequence) return

      this.payload = payload
      this.renderPayload(payload)
    } catch (error) {
      if (error.name === "AbortError" || sequence !== this.requestSequence) return

      this.showError(error.message)
    }
  }

  requestUrl() {
    const url = new URL(this.urlValue, window.location.origin)
    Object.entries(this.queryState()).forEach(([key, value]) => url.searchParams.set(key, value))
    return url
  }

  queryState() {
    return {
      from_date: this.fromDateTarget.value,
      to_date: this.toDateTarget.value,
      granularity: this.granularityTarget.value,
      paid_state: this.paidStateTarget.value,
      direction: this.directionTarget.value,
      sort: "date_asc"
    }
  }

  syncNavigationState() {
    const url = new URL(window.location.href)
    Object.entries(this.queryState()).forEach(([key, value]) => url.searchParams.set(key, value))
    window.history.replaceState(window.history.state, "", url)
  }

  renderPayload(payload) {
    if (!this.hasActivity(payload)) {
      this.payload = payload
      this.destroyChart()
      this.showEmpty()
      return
    }

    this.renderSummary(payload.summary)
    if (this.hasPaymentStateListTarget) this.renderEntries(this.paymentStateListTarget, payload.payment_states || [], "breakdown")
    if (this.hasBalanceContextTarget) this.renderBalanceContext(payload.balance_context)
    this.renderChart(payload.buckets)
    this.renderEntries(this.bucketListTarget, payload.buckets, "bucket")
    this.renderEntries(this.breakdownListTarget, payload.breakdowns, "breakdown")
    if (this.hasDetailListTarget) this.renderDetails(payload.details || [])
    this.showContent()
  }

  renderSummary(summary) {
    this.summaryIncomeTarget.textContent = this.formatCents(summary.income.amount_cents)
    this.summaryOutcomeTarget.textContent = this.formatCents(summary.outcome.amount_cents)
    this.summaryNetTarget.textContent = this.formatCents(summary.net_cents)
    this.applyNetTone(this.summaryNetTarget, summary.net_cents)
  }

  renderChart(buckets) {
    this.destroyChart()
    const theme = this.chartTheme()

    this.chart = new Chart(this.chartCanvasTarget, {
      type: "bar",
      data: {
        labels: buckets.map((bucket) => this.formatPeriod(bucket.key)),
        datasets: [
          this.chartDataset(this.label("income"), "income", buckets, "#059669"),
          this.chartDataset(this.label("outcome"), "outcome", buckets, "#e11d48")
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        animation: false,
        interaction: { mode: "nearest", intersect: true },
        onClick: (_event, elements) => this.openChartPoint(elements),
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: theme.tooltipBackground,
            borderColor: theme.tooltipBorder,
            borderWidth: 1,
            bodyColor: theme.tooltipText,
            titleColor: theme.tooltipText,
            callbacks: { label: (context) => `${context.dataset.label}: ${this.formatCurrency(context.parsed.y)}` }
          }
        },
        scales: {
          x: {
            ticks: { color: theme.text, maxRotation: 0 },
            grid: { display: false },
            border: { color: theme.axis }
          },
          y: {
            beginAtZero: true,
            ticks: { color: theme.mutedText, callback: (value) => this.formatCompactCurrency(value) },
            grid: { color: theme.grid },
            border: { color: theme.axis }
          }
        }
      }
    })
  }

  chartDataset(label, direction, buckets, color) {
    return {
      label,
      reportDirection: direction,
      data: buckets.map((bucket) => Number(bucket[direction].amount_cents || 0) / 100),
      backgroundColor: color,
      borderColor: color,
      borderWidth: 1,
      borderRadius: 5,
      barPercentage: 0.82,
      categoryPercentage: 0.72
    }
  }

  openChartPoint(elements) {
    const element = elements[0]
    if (!element || !this.payload) return

    const direction = this.chart.data.datasets[element.datasetIndex]?.reportDirection
    const metric = this.payload.buckets[element.index]?.[direction]
    const chunks = this.metricChunks(metric)
    if (chunks.length === 1) {
      window.location.assign(chunks[0].path)
      return
    }

    document.getElementById(this.bucketRowId(element.index))?.focus()
  }

  renderEntries(list, entries, kind) {
    list.replaceChildren()
    entries.forEach((entry, index) => {
      const row = document.createElement("li")
      row.className = "rounded-2xl border border-slate-200 bg-white p-3 dark:border-slate-700 dark:bg-slate-900"
      row.tabIndex = -1
      if (kind === "bucket") row.id = this.bucketRowId(index)

      const header = document.createElement("div")
      header.className = "flex min-w-0 items-center justify-between gap-3"
      header.append(this.entryLabel(entry, kind), this.netBadge(entry.net_cents))
      row.appendChild(header)

      const metrics = document.createElement("div")
      metrics.className = "mt-3 grid gap-3 md:grid-cols-2"
      metrics.append(this.metricCard("income", entry.income), this.metricCard("outcome", entry.outcome))
      row.appendChild(metrics)
      list.appendChild(row)
    })
  }

  renderBalanceContext(context) {
    this.balanceContextTarget.replaceChildren()
    this.balanceContextTarget.appendChild(this.balanceCard(this.label("current_account_balance"), context?.account_balance_cents))

    if (!context?.first_recorded) {
      this.balanceContextTarget.appendChild(this.balanceCard(this.label("no_recorded_balance"), null))
      return
    }

    this.balanceContextTarget.append(
      this.recordedBalanceCard(this.label("first_recorded"), context.first_recorded),
      this.recordedBalanceCard(this.label("latest_recorded"), context.latest_recorded)
    )
  }

  renderDetails(details) {
    this.detailListTarget.replaceChildren()
    details.forEach((detail) => this.detailListTarget.appendChild(this.detailCard(detail)))
  }

  detailCard(detail) {
    const row = document.createElement("li")
    row.className = "rounded-2xl border border-slate-200 bg-white p-3 dark:border-slate-700 dark:bg-slate-900"

    const header = document.createElement("div")
    header.className = "flex min-w-0 items-start justify-between gap-3"
    const description = document.createElement("p")
    description.className = "min-w-0 break-words text-sm font-bold text-slate-950 dark:text-slate-100"
    description.textContent = detail.description
    const amount = document.createElement("span")
    amount.className = "shrink-0 text-sm font-bold text-slate-950 dark:text-slate-100"
    amount.textContent = this.formatCents(detail.amount_cents)
    header.append(description, amount)
    row.appendChild(header)

    const metadata = document.createElement("dl")
    metadata.className = "mt-3 grid gap-2 text-xs sm:grid-cols-2 xl:grid-cols-3"
    metadata.append(
      this.metadataItem("purchase_date", this.formatDate(detail.purchase_date)),
      this.metadataItem("installment_date", this.formatDate(detail.installment_date)),
      this.metadataItem("billing_period", this.formatPeriod(detail.billing_period)),
      this.metadataItem("closing_date", this.optionalDate(detail.invoice?.closing_date)),
      this.metadataItem("due_date", this.optionalDate(detail.invoice?.due_date)),
      this.metadataItem("installment", `#${detail.installment_number}`),
      this.metadataItem(detail.paid ? "paid" : "pending", `#${detail.identity.installment_id}`),
      this.metadataItem("invoice", this.identityLabel("Reference", detail.invoice?.reference_id)),
      this.metadataItem("generated_payment", this.identityLabel("CashTransaction", detail.generated_payment?.cash_transaction_id))
    )
    if (detail.advance?.active) {
      metadata.appendChild(this.metadataItem("advance", this.identityLabel("CashTransaction", detail.advance.cash_transaction_id)))
    }
    row.appendChild(metadata)

    const link = document.createElement("a")
    link.href = detail.path
    link.className = "mt-3 inline-flex rounded-lg border border-sky-200 bg-sky-50 px-2.5 py-1.5 text-xs font-semibold text-sky-800 hover:bg-sky-100 " +
      "dark:border-sky-900 dark:bg-sky-950/40 dark:text-sky-300 dark:hover:bg-sky-900/50"
    link.dataset.turboFrame = "_top"
    link.dataset.turboPrefetch = "false"
    link.textContent = this.label("view_source")
    row.appendChild(link)
    return row
  }

  metadataItem(labelKey, value) {
    const wrapper = document.createElement("div")
    wrapper.className = "rounded-lg bg-slate-50 px-2.5 py-2 dark:bg-slate-950/70"
    const term = document.createElement("dt")
    term.className = "font-semibold text-slate-500 dark:text-slate-400"
    term.textContent = this.label(labelKey)
    const description = document.createElement("dd")
    description.className = "mt-0.5 break-words font-medium text-slate-900 dark:text-slate-100"
    description.textContent = value
    wrapper.append(term, description)
    return wrapper
  }

  optionalDate(value) {
    return value ? this.formatDate(value) : this.label("unavailable")
  }

  identityLabel(type, id) {
    return id ? `${type} #${id}` : this.label("unavailable")
  }

  balanceCard(labelText, amountCents, detail = null) {
    const card = document.createElement("div")
    card.className = "rounded-2xl border border-slate-200 bg-white px-4 py-3 dark:border-slate-700 dark:bg-slate-900"
    const label = document.createElement("p")
    label.className = "text-2xs font-semibold uppercase tracking-[0.18em] text-slate-500 dark:text-slate-400"
    label.textContent = labelText
    const amount = document.createElement("p")
    amount.className = "mt-2 text-lg font-bold text-slate-950 dark:text-slate-100"
    amount.textContent = amountCents === null || amountCents === undefined ? "—" : this.formatCents(amountCents)
    card.append(label, amount)

    if (detail) {
      const description = document.createElement("p")
      description.className = "mt-1 text-xs text-slate-500 dark:text-slate-400"
      description.textContent = detail
      card.appendChild(description)
    }

    return card
  }

  recordedBalanceCard(labelText, record) {
    const detail = `${this.label("recorded_on")} ${this.formatDate(record.occurred_on)}`
    return this.balanceCard(labelText, record.amount_cents, detail)
  }

  entryLabel(entry, kind) {
    const wrapper = document.createElement("div")
    wrapper.className = "flex min-w-0 items-center gap-2"

    if (kind === "breakdown" && entry.background) {
      const swatch = document.createElement("span")
      swatch.className = "size-3 shrink-0 rounded-full border"
      swatch.style.backgroundColor = entry.background
      swatch.style.borderColor = entry.foreground || entry.background
      swatch.setAttribute("aria-hidden", "true")
      wrapper.appendChild(swatch)
    }

    const label = document.createElement("span")
    label.className = "min-w-0 break-words text-sm font-bold text-slate-950 dark:text-slate-100"
    label.textContent = kind === "bucket" ? this.formatPeriod(entry.key) : entry.label
    wrapper.appendChild(label)
    return wrapper
  }

  netBadge(value) {
    const badge = document.createElement("span")
    badge.className = "shrink-0 rounded-full bg-slate-100 px-2.5 py-1 text-xs font-bold dark:bg-slate-800"
    badge.textContent = `${this.label("net")}: ${this.formatCents(value)}`
    this.applyNetTone(badge, value)
    return badge
  }

  metricCard(direction, metric) {
    const card = document.createElement("div")
    card.className = "rounded-xl border border-slate-100 bg-slate-50/80 p-3 dark:border-slate-800 dark:bg-slate-950/70"

    const header = document.createElement("div")
    header.className = "flex items-center justify-between gap-3"
    const label = document.createElement("span")
    label.className = "text-xs font-black uppercase tracking-[0.16em] text-slate-500 dark:text-slate-400"
    label.textContent = this.label(direction)
    const amount = document.createElement("span")
    amount.className = direction === "income" ? "font-bold text-emerald-700 dark:text-emerald-300" : "font-bold text-rose-700 dark:text-rose-300"
    amount.textContent = this.formatCents(metric.amount_cents)
    header.append(label, amount)
    card.appendChild(header)

    const links = document.createElement("div")
    links.className = "mt-2 flex flex-wrap gap-2"
    const chunks = this.metricChunks(metric)
    if (chunks.length === 0) {
      const empty = document.createElement("span")
      empty.className = "text-xs text-slate-400 dark:text-slate-500"
      empty.textContent = this.label("no_sources")
      links.appendChild(empty)
    } else {
      chunks.forEach((chunk) => links.appendChild(this.sourceLink(chunk)))
    }
    card.appendChild(links)
    return card
  }

  metricChunks(metric) {
    return ["cash", "card"].flatMap((type) => {
      const source = metric?.sources?.[type]
      const chunks = source?.chunks || []
      return chunks.map((chunk, index) => ({ ...chunk, type, index, totalChunks: chunks.length }))
    })
  }

  sourceLink(chunk) {
    const link = document.createElement("a")
    link.href = chunk.path
    link.className = "rounded-lg border border-sky-200 bg-sky-50 px-2 py-1 text-xs font-semibold text-sky-800 hover:bg-sky-100 " +
      "dark:border-sky-900 dark:bg-sky-950/40 dark:text-sky-300 dark:hover:bg-sky-900/50"
    link.dataset.turboFrame = "_top"
    link.dataset.turboPrefetch = "false"
    const chunkLabel = chunk.totalChunks > 1 ? ` ${this.label("chunk")} ${chunk.index + 1}/${chunk.totalChunks}` : ""
    link.textContent = `${this.label(chunk.type)}${chunkLabel} — ${this.formatCents(chunk.amount_cents)} (${chunk.count})`
    return link
  }

  bucketRowId(index) {
    return `${this.element.id}_bucket_${index}`
  }

  formatPeriod(value) {
    const date = new Date(`${value.length === 7 ? `${value}-01` : value}T12:00:00`)
    const options = value.length === 7 ? { month: "short", year: "numeric" } : { day: "2-digit", month: "short", year: "numeric" }
    return new Intl.DateTimeFormat(this.localeValue, options).format(date)
  }

  formatDate(value) {
    return new Intl.DateTimeFormat(this.localeValue, { dateStyle: "medium" }).format(new Date(`${value}T12:00:00`))
  }

  formatCents(value) {
    return this.formatCurrency((Number(value) || 0) / 100)
  }

  formatCurrency(value) {
    const number = Number(value) || 0
    const currency = new Intl.NumberFormat(this.localeValue, { style: "currency", currency: this.currencyValue })
      .formatToParts(0)
      .find((part) => part.type === "currency")?.value || this.currencyValue
    const amount = new Intl.NumberFormat(this.localeValue, { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(Math.abs(number))
    return `${currency} ${number < 0 ? "-" : ""}${amount}`
  }

  formatCompactCurrency(value) {
    const number = Number(value) || 0
    const currency = new Intl.NumberFormat(this.localeValue, { style: "currency", currency: this.currencyValue })
      .formatToParts(0)
      .find((part) => part.type === "currency")?.value || this.currencyValue
    const amount = new Intl.NumberFormat(this.localeValue, {
      notation: "compact",
      maximumFractionDigits: 1
    }).format(Math.abs(number))
    return `${currency} ${number < 0 ? "-" : ""}${amount}`
  }

  applyNetTone(element, value) {
    element.classList.toggle("text-emerald-700", value > 0)
    element.classList.toggle("dark:text-emerald-300", value > 0)
    element.classList.toggle("text-rose-700", value < 0)
    element.classList.toggle("dark:text-rose-300", value < 0)
    element.classList.toggle("text-slate-950", value === 0)
    element.classList.toggle("dark:text-slate-100", value === 0)
  }

  hasActivity(payload) {
    return Number(payload?.summary?.income?.source_count || 0) > 0 || Number(payload?.summary?.outcome?.source_count || 0) > 0
  }

  showLoading() {
    this.element.setAttribute("aria-busy", "true")
    this.toggleState(this.loadingStateTarget, true)
    this.toggleState(this.errorStateTarget, false)
    this.toggleState(this.emptyStateTarget, false)
    this.contentTarget.classList.add("hidden")
  }

  showError(message) {
    this.element.setAttribute("aria-busy", "false")
    this.errorMessageTarget.textContent = message || this.label("error")
    this.toggleState(this.loadingStateTarget, false)
    this.toggleState(this.errorStateTarget, true)
    this.toggleState(this.emptyStateTarget, false)
    this.contentTarget.classList.add("hidden")
  }

  showEmpty() {
    this.element.setAttribute("aria-busy", "false")
    this.toggleState(this.loadingStateTarget, false)
    this.toggleState(this.errorStateTarget, false)
    this.toggleState(this.emptyStateTarget, true)
    this.contentTarget.classList.add("hidden")
  }

  showContent() {
    this.element.setAttribute("aria-busy", "false")
    this.toggleState(this.loadingStateTarget, false)
    this.toggleState(this.errorStateTarget, false)
    this.toggleState(this.emptyStateTarget, false)
    this.contentTarget.classList.remove("hidden")
  }

  toggleState(target, visible) {
    target.classList.toggle("hidden", !visible)
    target.classList.toggle("flex", visible)
  }

  redrawChart() {
    if (!this.payload || this.contentTarget.classList.contains("hidden")) return

    this.renderChart(this.payload.buckets)
  }

  destroyChart() {
    this.chart?.destroy()
    this.chart = null
  }

  chartTheme() {
    if (document.documentElement.classList.contains("dark")) {
      return {
        text: "#e2e8f0",
        mutedText: "#94a3b8",
        grid: "rgba(100, 116, 139, 0.25)",
        axis: "rgba(100, 116, 139, 0.45)",
        tooltipBackground: "rgba(15, 23, 42, 0.96)",
        tooltipBorder: "rgba(100, 116, 139, 0.8)",
        tooltipText: "#f8fafc"
      }
    }

    return {
      text: "#334155",
      mutedText: "#64748b",
      grid: "rgba(148, 163, 184, 0.2)",
      axis: "rgba(100, 116, 139, 0.35)",
      tooltipBackground: "rgba(255, 255, 255, 0.98)",
      tooltipBorder: "rgba(100, 116, 139, 0.35)",
      tooltipText: "#0f172a"
    }
  }

  label(key) {
    return this.labelsValue[key] || key
  }
}
