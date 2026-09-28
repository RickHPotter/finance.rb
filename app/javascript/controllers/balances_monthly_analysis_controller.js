import { Controller } from "@hotwired/stimulus"
import { BarController, BarElement, CategoryScale, Chart, LinearScale, Tooltip } from "chart.js"
import { resolveCategoryChartPresentation } from "../lib/category_chart_presentation.mjs"
import { fetchReportJson, formatCompactReportCurrency, formatReportCurrency, showReportState } from "../lib/report_presentation.mjs"

Chart.register(BarController, BarElement, CategoryScale, LinearScale, Tooltip)

const CHART_TARGETS = [
  "incomeCategories",
  "outcomeCategories",
  "incomeEntities",
  "outcomeEntities"
]

export default class extends Controller {
  static values = {
    url: String,
    locale: String,
    currency: String,
    labels: Object
  }

  static targets = [
    "monthInput",
    "loadingState",
    "errorState",
    "errorMessage",
    "emptyState",
    "content",
    "summaryIncome",
    "summaryOutcome",
    "summaryNet",
    "incomeCategoriesCanvas",
    "incomeCategoriesList",
    "outcomeCategoriesCanvas",
    "outcomeCategoriesList",
    "incomeEntitiesCanvas",
    "incomeEntitiesList",
    "outcomeEntitiesCanvas",
    "outcomeEntitiesList",
    "transferSentTotal",
    "transferSentList",
    "transferReceivedTotal",
    "transferReceivedList",
    "transferFailedTotal",
    "transferFailedList",
    "piggyContributed",
    "piggyProjectedContribution",
    "piggyWithdrawn",
    "piggyProjectedWithdrawal",
    "piggyProfitLoss",
    "piggyGroupsList"
  ]

  connect() {
    this.charts = new Map()
    this.requestSequence = 0
    this.payload = null
    this.themeObserver = new MutationObserver(() => this.redrawCharts())
    this.themeObserver.observe(document.documentElement, { attributes: true, attributeFilter: ["class"] })
    this.syncNavigationState()
    this.load()
  }

  disconnect() {
    this.abortController?.abort()
    this.themeObserver?.disconnect()
    this.destroyCharts()
  }

  previousMonth() {
    this.moveMonth(-1)
  }

  nextMonth() {
    this.moveMonth(1)
  }

  changeMonth() {
    if (!this.validMonth(this.monthInputTarget.value)) return

    this.syncNavigationState()
    this.load()
  }

  retry() {
    this.load()
  }

  moveMonth(offset) {
    const [year, month] = this.monthInputTarget.value.split("-").map(Number)
    if (!year || !month) return

    const next = new Date(year, month - 1 + offset, 1)
    this.monthInputTarget.value = `${next.getFullYear()}-${String(next.getMonth() + 1).padStart(2, "0")}`
    this.syncNavigationState()
    this.load()
  }

  syncNavigationState() {
    if (!this.validMonth(this.monthInputTarget.value)) return
    if (!window.location.pathname.startsWith("/balances")) return

    const url = new URL(window.location.href)
    if (url.searchParams.get("month") === this.monthInputTarget.value) return

    url.searchParams.set("month", this.monthInputTarget.value)
    window.history.replaceState(window.history.state, "", url)
  }

  async load() {
    const selectedMonth = this.monthInputTarget.value
    if (!this.validMonth(selectedMonth)) return

    const sequence = ++this.requestSequence
    this.abortController?.abort()
    this.abortController = new AbortController()
    this.showLoading()

    try {
      const url = new URL(this.urlValue, window.location.origin)
      url.searchParams.set("month", selectedMonth)
      const payload = await fetchReportJson(url, this.abortController.signal, this.label("error"))
      if (sequence !== this.requestSequence) return

      this.payload = payload
      this.renderPayload(payload)
    } catch (error) {
      if (error.name === "AbortError" || sequence !== this.requestSequence) return

      this.showError(error.message)
    }
  }

  renderPayload(payload) {
    if (!this.hasActivity(payload)) {
      this.destroyCharts()
      this.showEmpty()
      return
    }

    this.renderSummary(payload.ordinary)
    this.renderBreakdowns(payload.ordinary)
    this.renderTransfers(payload.transfers)
    this.renderPiggyBanks(payload.piggy_banks)
    this.showContent()
  }

  renderSummary(ordinary) {
    this.summaryIncomeTarget.textContent = this.formatCurrency(ordinary.income.total)
    this.summaryOutcomeTarget.textContent = this.formatCurrency(ordinary.outcome.total)
    this.summaryNetTarget.textContent = this.formatCurrency(ordinary.net)
    this.summaryNetTarget.classList.toggle("text-emerald-700", ordinary.net > 0)
    this.summaryNetTarget.classList.toggle("dark:text-emerald-300", ordinary.net > 0)
    this.summaryNetTarget.classList.toggle("text-rose-700", ordinary.net < 0)
    this.summaryNetTarget.classList.toggle("dark:text-rose-300", ordinary.net < 0)
    this.summaryNetTarget.classList.toggle("text-stone-900", ordinary.net === 0)
    this.summaryNetTarget.classList.toggle("dark:text-slate-100", ordinary.net === 0)
  }

  renderBreakdowns(ordinary) {
    this.renderBreakdown("incomeCategories", ordinary.income.categories, "#047857")
    this.renderBreakdown("outcomeCategories", ordinary.outcome.categories, "#be123c")
    this.renderBreakdown("incomeEntities", ordinary.income.entities, "#0369a1")
    this.renderBreakdown("outcomeEntities", ordinary.outcome.entities, "#c2410c")
  }

  renderBreakdown(name, entries, color) {
    const canvas = this[`${name}CanvasTarget`]
    const list = this[`${name}ListTarget`]
    const normalizedEntries = (entries || []).map((entry) => ({ ...entry, amount: Math.abs(Number(entry.amount) || 0) }))

    const presentations = normalizedEntries.map((entry) => this.entryPresentation(entry, color))

    this.renderRankedList(list, normalizedEntries, presentations)
    this.destroyChart(name)

    if (normalizedEntries.length === 0) {
      canvas.classList.add("invisible")
      return
    }

    canvas.classList.remove("invisible")
    const theme = this.chartTheme()
    this.charts.set(name, new Chart(canvas, {
      type: "bar",
      data: {
        labels: normalizedEntries.map((entry) => entry.label),
        datasets: [{
          data: normalizedEntries.map((entry) => entry.amount),
          backgroundColor: presentations.map((presentation) => presentation.background),
          borderColor: presentations.map((presentation) => presentation.foreground),
          borderWidth: 1,
          borderRadius: 4,
          barThickness: 18
        }]
      },
      options: {
        indexAxis: "y",
        responsive: true,
        maintainAspectRatio: false,
        animation: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: theme.tooltipBackground,
            borderColor: theme.tooltipBorder,
            borderWidth: 1,
            bodyColor: theme.tooltipText,
            titleColor: theme.tooltipText,
            callbacks: { label: (context) => this.formatCurrency(context.parsed.x) }
          }
        },
        scales: {
          x: {
            beginAtZero: true,
            ticks: { color: theme.mutedText, callback: (value) => this.formatCompactCurrency(value) },
            grid: { color: theme.grid }
          },
          y: {
            ticks: { color: theme.text, callback: (_, index) => this.truncateLabel(normalizedEntries[index]?.label) },
            grid: { display: false }
          }
        }
      }
    }))
  }

  renderRankedList(list, entries, presentations) {
    list.replaceChildren()
    if (entries.length === 0) {
      list.appendChild(this.emptyListItem())
      return
    }

    entries.forEach((entry, index) => {
      const row = document.createElement("li")
      row.className = "flex min-w-0 items-start justify-between gap-3 border-t border-stone-100 pt-2 text-sm dark:border-slate-800"

      const label = document.createElement("span")
      label.className = "min-w-0 break-words rounded-md border px-2 py-1 font-semibold"
      label.title = entry.label
      label.textContent = `${index + 1}. ${entry.label}`
      label.style.backgroundColor = presentations[index].background
      label.style.color = presentations[index].foreground
      label.style.borderColor = presentations[index].foreground

      const amount = document.createElement("span")
      amount.className = "shrink-0 font-semibold text-stone-900 dark:text-slate-100"
      amount.textContent = this.formatCurrency(entry.amount)

      row.append(label, amount)
      list.appendChild(row)
    })
  }

  entryPresentation(entry, fallbackBackground) {
    return resolveCategoryChartPresentation(entry, fallbackBackground)
  }

  renderTransfers(transfers) {
    const sent = (transfers.items || []).filter((item) => item.direction === "sent")
    const received = (transfers.items || []).filter((item) => item.direction === "received")
    const failed = transfers.failed || []

    this.transferSentTotalTarget.textContent = this.formatCurrency(transfers.total_sent)
    this.transferReceivedTotalTarget.textContent = this.formatCurrency(transfers.total_received)
    this.transferFailedTotalTarget.textContent = this.formatCurrency(transfers.total_failed)
    this.renderActivityList(this.transferSentListTarget, sent, "entity_label")
    this.renderActivityList(this.transferReceivedListTarget, received, "entity_label")
    this.renderActivityList(this.transferFailedListTarget, failed, "entity_label")
  }

  renderActivityList(list, items, labelKey) {
    list.replaceChildren()
    if (items.length === 0) {
      list.appendChild(this.emptyListItem())
      return
    }

    items.forEach((item) => list.appendChild(this.amountRow(item[labelKey], item.amount, item.sources || [])))
  }

  renderPiggyBanks(piggyBanks) {
    this.piggyContributedTarget.textContent = this.formatCurrency(piggyBanks.total_contributed)
    this.piggyProjectedContributionTarget.textContent = this.formatCurrency(piggyBanks.total_projected_contribution)
    this.piggyWithdrawnTarget.textContent = this.formatCurrency(piggyBanks.total_withdrawn)
    this.piggyProjectedWithdrawalTarget.textContent = this.formatCurrency(piggyBanks.total_projected_withdrawal)
    this.piggyProfitLossTarget.textContent = this.formatCurrency(piggyBanks.recognized_profit_loss)
    this.piggyGroupsListTarget.replaceChildren()

    if ((piggyBanks.groups || []).length === 0) {
      this.piggyGroupsListTarget.appendChild(this.emptyListItem())
      return
    }

    piggyBanks.groups.forEach((group) => this.piggyGroupsListTarget.appendChild(this.piggyGroup(group)))
  }

  piggyGroup(group) {
    const item = document.createElement("li")
    item.className = "rounded-lg border border-stone-200 p-4 dark:border-slate-700"

    const title = document.createElement("p")
    title.className = "break-words text-sm font-semibold text-stone-900 dark:text-slate-100"
    title.textContent = group.label
    item.appendChild(title)

    if (group.return_path) {
      item.appendChild(this.sourceLink({
        identity: group.return_identity,
        origin: "generated_return",
        role: "piggy_bank_return",
        path: group.return_path
      }))
    }

    const metrics = document.createElement("dl")
    metrics.className = "mt-3 grid grid-cols-2 gap-3 lg:grid-cols-5"
    const values = [
      ["contributed", group.contributed, false],
      ["projected_contribution", group.projected_contribution, true],
      ["withdrawn", group.withdrawn, false],
      ["projected_withdrawal", group.projected_withdrawal, true],
      ["recognized_profit_loss", group.recognized_profit_loss, false]
    ]

    values.forEach(([key, value, projected]) => {
      metrics.appendChild(this.metricDefinition(this.label(key), value, projected, group.sources?.[key] || []))
    })
    item.appendChild(metrics)
    return item
  }

  metricDefinition(labelText, value, projected, sources) {
    const wrapper = document.createElement("div")
    wrapper.className = projected ? "border-l-2 border-dashed border-amber-500 pl-2" : "border-l-2 border-stone-300 pl-2 dark:border-slate-600"

    const label = document.createElement("dt")
    label.className = "text-xs text-stone-500 dark:text-slate-400"
    label.textContent = labelText

    const amount = document.createElement("dd")
    amount.className = "mt-1 text-sm font-semibold text-stone-900 dark:text-slate-100"
    amount.textContent = this.formatCurrency(value)

    wrapper.append(label, amount)
    if (sources.length) wrapper.appendChild(this.sourceLinks(sources))
    return wrapper
  }

  amountRow(labelText, value, sources = []) {
    const row = document.createElement("li")
    row.className = "min-w-0 border-t border-stone-100 pt-2 text-sm dark:border-slate-800"

    const summary = document.createElement("div")
    summary.className = "flex min-w-0 items-start justify-between gap-3"

    const label = document.createElement("span")
    label.className = "min-w-0 break-words text-stone-700 dark:text-slate-300"
    label.textContent = labelText

    const amount = document.createElement("span")
    amount.className = "shrink-0 font-semibold text-stone-900 dark:text-slate-100"
    amount.textContent = this.formatCurrency(value)

    summary.append(label, amount)
    row.appendChild(summary)
    if (sources.length) row.appendChild(this.sourceLinks(sources))
    return row
  }

  sourceLinks(sources) {
    const links = document.createElement("div")
    links.className = "mt-2 flex flex-wrap gap-1.5"
    sources.forEach((source) => links.appendChild(this.sourceLink(source)))
    return links
  }

  sourceLink(source) {
    const link = document.createElement("a")
    link.href = source.path
    link.className = "inline-flex max-w-full items-center rounded-md border border-sky-200 bg-sky-50 px-2 py-1 text-2xs font-semibold text-sky-800 " +
      "hover:bg-sky-100 dark:border-sky-900 dark:bg-sky-950/40 dark:text-sky-300 dark:hover:bg-sky-900/50"
    link.dataset.turboFrame = "_top"
    link.dataset.turboPrefetch = "false"
    link.title = this.label("view_source")
    const amount = source.amount_cents === null || source.amount_cents === undefined ? "" : ` — ${this.formatCurrency(source.amount_cents / 100)}`
    link.textContent = `${this.label(source.origin)} · ${source.identity.record_type} #${source.identity.record_id}${amount}`
    return link
  }

  emptyListItem() {
    const item = document.createElement("li")
    item.className = "py-2 text-sm text-stone-400 dark:text-slate-500"
    item.textContent = this.label("no_items")
    return item
  }

  showLoading() {
    showReportState(this.element, this.reportStateTargets(), "loading")
  }

  showError(message) {
    this.errorMessageTarget.textContent = message || this.label("error")
    showReportState(this.element, this.reportStateTargets(), "error")
  }

  showEmpty() {
    showReportState(this.element, this.reportStateTargets(), "empty")
  }

  showContent() {
    showReportState(this.element, this.reportStateTargets(), "content")
  }

  reportStateTargets() {
    return {
      loading: this.loadingStateTarget,
      error: this.errorStateTarget,
      empty: this.emptyStateTarget,
      content: this.contentTarget
    }
  }

  hasActivity(payload) {
    const ordinary = payload.ordinary
    const transfers = payload.transfers
    const piggyBanks = payload.piggy_banks

    return Number(ordinary.income.total) !== 0 ||
      Number(ordinary.outcome.total) !== 0 ||
      (transfers.items || []).length > 0 ||
      (transfers.failed || []).length > 0 ||
      (piggyBanks.groups || []).length > 0
  }

  redrawCharts() {
    if (!this.payload || this.contentTarget.classList.contains("hidden")) return

    this.renderBreakdowns(this.payload.ordinary)
  }

  destroyChart(name) {
    this.charts.get(name)?.destroy()
    this.charts.delete(name)
  }

  destroyCharts() {
    CHART_TARGETS.forEach((name) => this.destroyChart(name))
  }

  formatCurrency(value) {
    return formatReportCurrency(value, this.localeValue, this.currencyValue)
  }

  formatCompactCurrency(value) {
    return formatCompactReportCurrency(value, this.localeValue, this.currencyValue)
  }

  chartTheme() {
    if (document.documentElement.classList.contains("dark")) {
      return {
        text: "#e2e8f0",
        mutedText: "#94a3b8",
        grid: "rgba(100, 116, 139, 0.25)",
        tooltipBackground: "rgba(15, 23, 42, 0.96)",
        tooltipBorder: "rgba(100, 116, 139, 0.8)",
        tooltipText: "#f8fafc"
      }
    }

    return {
      text: "#44403c",
      mutedText: "#78716c",
      grid: "rgba(120, 113, 108, 0.18)",
      tooltipBackground: "rgba(255, 255, 255, 0.98)",
      tooltipBorder: "rgba(120, 113, 108, 0.35)",
      tooltipText: "#1c1917"
    }
  }

  truncateLabel(label) {
    if (!label || label.length <= 24) return label

    return `${label.slice(0, 21)}...`
  }

  validMonth(value) {
    return /^\d{4}-(0[1-9]|1[0-2])$/.test(value)
  }

  label(key) {
    return this.labelsValue[key] || key
  }

}
