import { Controller } from "@hotwired/stimulus"
import { BarController, BarElement, CategoryScale, Chart, LinearScale, Tooltip } from "chart.js"

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
    if (this.validMonth(this.monthInputTarget.value)) this.load()
  }

  retry() {
    this.load()
  }

  moveMonth(offset) {
    const [year, month] = this.monthInputTarget.value.split("-").map(Number)
    if (!year || !month) return

    const next = new Date(year, month - 1 + offset, 1)
    this.monthInputTarget.value = `${next.getFullYear()}-${String(next.getMonth() + 1).padStart(2, "0")}`
    this.load()
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
      const response = await fetch(url, {
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

    this.renderRankedList(list, normalizedEntries, color)
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
        datasets: [{ data: normalizedEntries.map((entry) => entry.amount), backgroundColor: color, borderRadius: 4, barThickness: 18 }]
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
            bodyColor: theme.text,
            titleColor: theme.text,
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

  renderRankedList(list, entries, color) {
    list.replaceChildren()
    if (entries.length === 0) {
      list.appendChild(this.emptyListItem())
      return
    }

    entries.forEach((entry, index) => {
      const row = document.createElement("li")
      row.className = "flex min-w-0 items-start justify-between gap-3 border-t border-stone-100 pt-2 text-sm dark:border-slate-800"

      const label = document.createElement("span")
      label.className = "min-w-0 break-words text-stone-700 dark:text-slate-300"
      label.title = entry.label
      label.textContent = `${index + 1}. ${entry.label}`
      label.style.borderInlineStart = `3px solid ${color}`
      label.style.paddingInlineStart = "0.5rem"

      const amount = document.createElement("span")
      amount.className = "shrink-0 font-semibold text-stone-900 dark:text-slate-100"
      amount.textContent = this.formatCurrency(entry.amount)

      row.append(label, amount)
      list.appendChild(row)
    })
  }

  renderTransfers(transfers) {
    const sent = (transfers.items || []).filter((item) => item.direction === "sent")
    const received = (transfers.items || []).filter((item) => item.direction === "received")
    const failed = transfers.failed || []

    this.transferSentTotalTarget.textContent = this.formatCurrency(transfers.total_sent)
    this.transferReceivedTotalTarget.textContent = this.formatCurrency(transfers.total_received)
    this.transferFailedTotalTarget.textContent = this.formatCurrency(this.sum(failed, "amount"))
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

    items.forEach((item) => list.appendChild(this.amountRow(item[labelKey], item.amount)))
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

    const metrics = document.createElement("dl")
    metrics.className = "mt-3 grid grid-cols-2 gap-3 lg:grid-cols-5"
    const values = [
      ["contributed", group.contributed, false],
      ["projected_contribution", group.projected_contribution, true],
      ["withdrawn", group.withdrawn, false],
      ["projected_withdrawal", group.projected_withdrawal, true],
      ["recognized_profit_loss", group.recognized_profit_loss, false]
    ]

    values.forEach(([key, value, projected]) => metrics.appendChild(this.metricDefinition(this.label(key), value, projected)))
    item.appendChild(metrics)
    return item
  }

  metricDefinition(labelText, value, projected) {
    const wrapper = document.createElement("div")
    wrapper.className = projected ? "border-l-2 border-dashed border-amber-500 pl-2" : "border-l-2 border-stone-300 pl-2 dark:border-slate-600"

    const label = document.createElement("dt")
    label.className = "text-xs text-stone-500 dark:text-slate-400"
    label.textContent = labelText

    const amount = document.createElement("dd")
    amount.className = "mt-1 text-sm font-semibold text-stone-900 dark:text-slate-100"
    amount.textContent = this.formatCurrency(value)

    wrapper.append(label, amount)
    return wrapper
  }

  amountRow(labelText, value) {
    const row = document.createElement("li")
    row.className = "flex min-w-0 items-start justify-between gap-3 border-t border-stone-100 pt-2 text-sm dark:border-slate-800"

    const label = document.createElement("span")
    label.className = "min-w-0 break-words text-stone-700 dark:text-slate-300"
    label.textContent = labelText

    const amount = document.createElement("span")
    amount.className = "shrink-0 font-semibold text-stone-900 dark:text-slate-100"
    amount.textContent = this.formatCurrency(value)

    row.append(label, amount)
    return row
  }

  emptyListItem() {
    const item = document.createElement("li")
    item.className = "py-2 text-sm text-stone-400 dark:text-slate-500"
    item.textContent = this.label("no_items")
    return item
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
    return new Intl.NumberFormat(this.localeValue, {
      style: "currency",
      currency: this.currencyValue
    }).format(Number(value) || 0)
  }

  formatCompactCurrency(value) {
    return new Intl.NumberFormat(this.localeValue, {
      style: "currency",
      currency: this.currencyValue,
      notation: "compact",
      maximumFractionDigits: 1
    }).format(Number(value) || 0)
  }

  chartTheme() {
    if (document.documentElement.classList.contains("dark")) {
      return {
        text: "#e2e8f0",
        mutedText: "#94a3b8",
        grid: "rgba(100, 116, 139, 0.25)",
        tooltipBackground: "rgba(15, 23, 42, 0.96)"
      }
    }

    return {
      text: "#44403c",
      mutedText: "#78716c",
      grid: "rgba(120, 113, 108, 0.18)",
      tooltipBackground: "rgba(28, 25, 23, 0.94)"
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

  sum(items, key) {
    return items.reduce((total, item) => total + (Number(item[key]) || 0), 0)
  }
}
