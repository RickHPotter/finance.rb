import { Controller } from "@hotwired/stimulus"
import { BarController, BarElement, CategoryScale, Chart, Legend, LinearScale, Tooltip } from "chart.js"
import { formatCompactReportCurrency, formatReportCurrency } from "../lib/report_presentation.mjs"

Chart.register(BarController, BarElement, CategoryScale, Legend, LinearScale, Tooltip)

export default class extends Controller {
  static values = { data: Object, locale: String, currency: String, labels: Object }
  static targets = ["primarySelect", "groupActions", "groupOptions", "secondaryActions", "secondaryOptions", "chartCanvas", "emptyState"]

  connect() {
    this.chart = null
    this.selectedSecondaryIds = new Set()
    this.themeObserver = new MutationObserver(() => this.renderChart())
    this.themeObserver.observe(document.documentElement, { attributes: true, attributeFilter: ["class"] })
    this.renderPayload()
  }

  disconnect() {
    this.themeObserver?.disconnect()
    this.destroyChart()
  }

  dataValueChanged() {
    if (!this.hasPrimarySelectTarget) return

    this.renderPayload()
  }

  changePrimary() {
    this.selectDefaultGroup()
  }

  toggleGroup(event) {
    this.selectedGroupId = event.currentTarget.dataset.groupId
    this.renderGroups()
    this.selectAllSecondaryItems()
  }

  selectAllGroups() {
    this.selectedGroupId = "__combined__"
    this.renderGroups()
    this.selectAllSecondaryItems()
  }

  unselectAllGroups() {
    this.selectedGroupId = null
    this.renderGroups()
    this.selectAllSecondaryItems()
  }

  selectAllSecondaryItems() {
    this.selectedSecondaryIds = new Set(this.currentSecondaryItems().map((item) => item.id))
    this.renderSecondaryItems()
    this.renderChart()
  }

  unselectAllSecondaryItems() {
    this.selectedSecondaryIds = new Set()
    this.renderSecondaryItems()
    this.renderChart()
  }

  toggleSecondaryItem(event) {
    const id = event.currentTarget.dataset.secondaryId
    if (this.selectedSecondaryIds.has(id)) this.selectedSecondaryIds.delete(id)
    else this.selectedSecondaryIds.add(id)

    this.renderSecondaryItems()
    this.renderChart()
  }

  renderPayload() {
    const previousPrimaryId = this.primarySelectTarget.value
    this.primarySelectTarget.replaceChildren()
    ;(this.dataValue.items || []).forEach((item) => {
      const option = document.createElement("option")
      option.value = item.id
      option.textContent = item.name
      this.primarySelectTarget.appendChild(option)
    })

    if ((this.dataValue.items || []).some((item) => item.id === previousPrimaryId)) this.primarySelectTarget.value = previousPrimaryId
    this.selectDefaultGroup()
  }

  selectDefaultGroup() {
    this.selectedGroupId = this.currentGroups().find((group) => group.id === "__all__")?.id || this.currentGroups()[0]?.id
    this.renderGroups()
    this.selectAllSecondaryItems()
  }

  renderGroups() {
    this.groupActionsTarget.replaceChildren(
      this.actionButton(this.label("select_all"), () => this.selectAllGroups(), this.selectedGroupId === "__combined__"),
      this.actionButton(this.label("unselect_all"), () => this.unselectAllGroups(), this.selectedGroupId === null)
    )
    this.groupOptionsTarget.replaceChildren()
    this.currentGroups().forEach((group) => {
      const button = this.button(group.label, this.selectedGroupId === group.id)
      button.dataset.groupId = group.id
      button.addEventListener("click", (event) => this.toggleGroup(event))
      this.groupOptionsTarget.appendChild(button)
    })
  }

  renderSecondaryItems() {
    this.secondaryActionsTarget.replaceChildren(
      this.actionButton(this.label("select_all"), () => this.selectAllSecondaryItems(), this.allSecondarySelected()),
      this.actionButton(this.label("unselect_all"), () => this.unselectAllSecondaryItems(), this.selectedSecondaryIds.size === 0)
    )
    this.secondaryOptionsTarget.replaceChildren()

    this.currentSecondaryItems().forEach((item) => {
      const selected = this.selectedSecondaryIds.has(item.id)
      const button = this.button("", selected)
      button.dataset.secondaryId = item.id
      button.addEventListener("click", (event) => this.toggleSecondaryItem(event))
      this.appendVisual(button, item)

      const name = document.createElement("span")
      name.className = "break-words"
      name.textContent = item.name
      const total = document.createElement("span")
      total.className = `ml-auto rounded-full px-2 py-1 text-2xs font-black ${selected ? "bg-sky-200 text-sky-950 dark:bg-sky-900 dark:text-sky-100" : "bg-slate-200 text-slate-700 dark:bg-slate-800 dark:text-slate-300"}`
      total.textContent = this.formatCents(item.total_cents)
      button.append(name, total)
      this.secondaryOptionsTarget.appendChild(button)
    })
  }

  renderChart() {
    if (!this.chartCanvasTarget) return

    const items = this.currentSecondaryItems().filter((item) => this.selectedSecondaryIds.has(item.id))
    this.destroyChart()
    if (items.length === 0) {
      this.chartCanvasTarget.classList.add("hidden")
      this.emptyStateTarget.classList.remove("hidden")
      this.emptyStateTarget.classList.add("flex")
      return
    }

    this.chartCanvasTarget.classList.remove("hidden")
    this.emptyStateTarget.classList.add("hidden")
    this.emptyStateTarget.classList.remove("flex")
    const periods = this.dataValue.periods || []
    const theme = this.chartTheme()
    this.chart = new Chart(this.chartCanvasTarget, {
      type: "bar",
      data: {
        labels: periods.map((period) => this.formatPeriod(period)),
        datasets: items.map((item, index) => this.dataset(item, periods, index))
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        animation: false,
        interaction: { mode: "index", intersect: false },
        plugins: {
          legend: { position: "top", align: "start", labels: { color: theme.text, usePointStyle: true, pointStyle: "circle" } },
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
          x: { ticks: { color: theme.mutedText, maxRotation: 0 }, grid: { display: false } },
          y: {
            ticks: { color: theme.mutedText, callback: (value) => this.formatCompactCurrency(value) },
            grid: { color: theme.grid }
          }
        }
      }
    })
  }

  dataset(item, periods, index) {
    const amounts = new Map((item.points || []).map((point) => [point.x, Number(point.amount_cents || 0) / 100]))
    const presentation = item.chart_presentation || this.palette(index)

    return {
      label: item.name,
      data: periods.map((period) => amounts.get(period) || 0),
      backgroundColor: presentation.background,
      borderColor: presentation.foreground,
      borderWidth: 1,
      borderRadius: 5
    }
  }

  appendVisual(button, item) {
    const avatarPaths = item.avatar_paths || []
    if (avatarPaths.length > 0) {
      const wrapper = document.createElement("span")
      wrapper.className = "flex -space-x-2"
      avatarPaths.slice(0, 3).forEach((path) => {
        const image = document.createElement("img")
        image.src = path
        image.alt = ""
        image.className = "h-6 w-6 rounded-full border-2 border-white dark:border-slate-900"
        wrapper.appendChild(image)
      })
      button.appendChild(wrapper)
      return
    }

    const swatches = item.swatches || []
    if (swatches.length === 0) return

    const wrapper = document.createElement("span")
    wrapper.className = "flex -space-x-1"
    wrapper.setAttribute("aria-hidden", "true")
    swatches.forEach((swatch) => {
      const mark = document.createElement("span")
      mark.className = "h-5 w-5 rounded-full border-2"
      mark.style.backgroundColor = swatch.background
      mark.style.borderColor = swatch.foreground
      wrapper.appendChild(mark)
    })
    button.appendChild(wrapper)
  }

  button(label, active) {
    const button = document.createElement("button")
    button.type = "button"
    button.textContent = label
    button.setAttribute("aria-pressed", String(active))
    button.className = `inline-flex min-h-11 items-center gap-2 rounded-lg border px-3 py-2 text-left text-sm font-semibold transition ${active ?
      "border-sky-500 bg-sky-50 text-sky-950 dark:bg-sky-950/50 dark:text-sky-100" :
      "border-slate-300 bg-white text-slate-700 hover:bg-slate-50 dark:border-slate-700 dark:bg-slate-900 dark:text-slate-300 dark:hover:bg-slate-800"}`
    return button
  }

  actionButton(label, action, active) {
    const button = this.button(label, active)
    button.addEventListener("click", action)
    return button
  }

  currentPrimary() {
    return (this.dataValue.items || []).find((item) => item.id === this.primarySelectTarget.value)
  }

  currentGroups() {
    return this.currentPrimary()?.groups || []
  }

  currentSecondaryItems() {
    if (this.selectedGroupId === "__combined__") return this.currentPrimary()?.all_secondary_items || []
    if (this.selectedGroupId === null) return []

    return this.currentGroups().find((group) => group.id === this.selectedGroupId)?.secondary_items || []
  }

  allSecondarySelected() {
    const items = this.currentSecondaryItems()
    return items.length > 0 && items.every((item) => this.selectedSecondaryIds.has(item.id))
  }

  formatCents(value) {
    return this.formatCurrency((Number(value) || 0) / 100)
  }

  formatCurrency(value) {
    return formatReportCurrency(value, this.localeValue, this.currencyValue)
  }

  formatCompactCurrency(value) {
    return formatCompactReportCurrency(value, this.localeValue, this.currencyValue)
  }

  formatPeriod(value) {
    const date = new Date(`${value}T12:00:00`)
    const options = this.dataValue.granularity === "day" ? { day: "2-digit", month: "short" } : { month: "short", year: "numeric" }
    return new Intl.DateTimeFormat(this.localeValue, options).format(date)
  }

  destroyChart() {
    this.chart?.destroy()
    this.chart = null
  }

  chartTheme() {
    if (document.documentElement.classList.contains("dark")) {
      return {
        text: "#e2e8f0", mutedText: "#94a3b8", grid: "rgba(100, 116, 139, 0.25)",
        tooltipBackground: "rgba(15, 23, 42, 0.96)", tooltipBorder: "rgba(100, 116, 139, 0.8)", tooltipText: "#f8fafc"
      }
    }

    return {
      text: "#334155", mutedText: "#64748b", grid: "rgba(148, 163, 184, 0.2)",
      tooltipBackground: "rgba(255, 255, 255, 0.98)", tooltipBorder: "rgba(100, 116, 139, 0.35)", tooltipText: "#0f172a"
    }
  }

  palette(index) {
    const colors = [
      ["#dbeafe", "#1d4ed8"], ["#ede9fe", "#6d28d9"], ["#ffedd5", "#c2410c"],
      ["#ccfbf1", "#0f766e"], ["#ffe4e6", "#be123c"], ["#cffafe", "#0e7490"]
    ]
    const [background, foreground] = colors[index % colors.length]
    return { background, foreground }
  }

  label(key) {
    return this.labelsValue[key] || key
  }
}
