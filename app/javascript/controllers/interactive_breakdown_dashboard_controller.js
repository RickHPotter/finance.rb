import { Controller } from "@hotwired/stimulus"
import {
  BarController,
  CategoryScale,
  Chart,
  Filler,
  Legend,
  LinearScale,
  BarElement,
  Tooltip
} from "chart.js"

Chart.register(BarController, BarElement, LinearScale, CategoryScale, Tooltip, Legend, Filler)

export default class extends Controller {
  static targets = ["primarySelect", "groupActions", "groupOptions", "secondaryActions", "secondaryOptions", "chartCanvas", "emptyState"]
  static values = { data: Object }

  connect() {
    this.selectedGroupIds = new Set()
    this.selectedSecondaryIds = new Set()
    this.chart = null
    this.renderCurrentPrimary()
  }

  disconnect() {
    this.destroyChart()
  }

  changePrimary() {
    this.renderCurrentPrimary()
  }

  selectAllGroups() {
    this.selectedGroupIds = new Set(this.currentGroups().map((group) => group.id))
    this.renderGroupToolbar()
    this.resetSelectedSecondaryItems()
    this.renderSecondaryToolbar()
    this.renderChart()
  }

  unselectAllGroups() {
    this.selectedGroupIds = new Set()
    this.renderGroupToolbar()
    this.resetSelectedSecondaryItems()
    this.renderSecondaryToolbar()
    this.renderChart()
  }

  toggleGroup(event) {
    const { groupId } = event.currentTarget.dataset
    if (!groupId) return

    this.selectedGroupIds = new Set([groupId])
    this.renderGroupToolbar()
    this.resetSelectedSecondaryItems()
    this.renderSecondaryToolbar()
    this.renderChart()
  }

  selectAllSecondaryItems() {
    this.selectedSecondaryIds = new Set(this.currentSecondaryItems().map((item) => item.id))
    this.renderSecondaryToolbar()
    this.renderChart()
  }

  unselectAllSecondaryItems() {
    this.selectedSecondaryIds = new Set()
    this.renderSecondaryToolbar()
    this.renderChart()
  }

  toggleSecondaryItem(event) {
    const { secondaryId } = event.currentTarget.dataset
    if (!secondaryId) return

    this.selectedSecondaryIds = new Set([secondaryId])
    this.renderSecondaryToolbar()
    this.renderChart()
  }

  renderCurrentPrimary() {
    this.selectedGroupIds = new Set([this.defaultGroupId()])
    this.renderGroupToolbar()
    this.resetSelectedSecondaryItems()
    this.renderSecondaryToolbar()
    this.renderChart()
  }

  renderGroupToolbar() {
    const groups = this.currentGroups()
    this.groupActionsTarget.innerHTML = ""
    this.groupOptionsTarget.innerHTML = ""

    this.groupActionsTarget.appendChild(
      this.buildActionButton("Select All", () => this.selectAllGroups(), this.selectedGroupIds.size === groups.length && groups.length > 0)
    )
    this.groupActionsTarget.appendChild(
      this.buildActionButton("Unselect All", () => this.unselectAllGroups(), this.selectedGroupIds.size === 0)
    )

    groups.forEach((group) => {
      const button = document.createElement("button")
      button.type = "button"
      button.dataset.groupId = group.id
      button.addEventListener("click", (event) => this.toggleGroup(event))
      button.className = this.filterButtonClass(this.selectedGroupIds.has(group.id))
      button.textContent = group.label
      this.groupOptionsTarget.appendChild(button)
    })
  }

  renderSecondaryToolbar() {
    const secondaryItems = this.currentSecondaryItems()
    this.secondaryActionsTarget.innerHTML = ""
    this.secondaryOptionsTarget.innerHTML = ""

    this.secondaryActionsTarget.appendChild(
      this.buildActionButton(
        "Select All",
        () => this.selectAllSecondaryItems(),
        this.selectedSecondaryIds.size === secondaryItems.length && secondaryItems.length > 0
      )
    )
    this.secondaryActionsTarget.appendChild(
      this.buildActionButton("Unselect All", () => this.unselectAllSecondaryItems(), this.selectedSecondaryIds.size === 0)
    )

    secondaryItems.forEach((item) => {
      const button = document.createElement("button")
      button.type = "button"
      button.dataset.secondaryId = item.id
      button.addEventListener("click", (event) => this.toggleSecondaryItem(event))
      button.className = this.secondaryButtonClass(this.selectedSecondaryIds.has(item.id))

      this.appendSecondaryVisual(button, item)

      const name = document.createElement("span")
      name.className = "break-words"
      name.textContent = item.name
      button.appendChild(name)

      const total = document.createElement("span")
      total.className = this.secondaryTotalClass(this.selectedSecondaryIds.has(item.id))
      total.textContent = this.formatCurrency(item.total)
      button.appendChild(total)

      this.secondaryOptionsTarget.appendChild(button)
    })
  }

  appendSecondaryVisual(button, item) {
    if ((item.avatarPaths || []).length > 1) {
      const stack = document.createElement("span")
      stack.className = "flex -space-x-2"
      item.avatarPaths.slice(0, 3).forEach((avatarPath) => {
        const avatar = document.createElement("img")
        avatar.src = avatarPath
        avatar.alt = item.name
        avatar.className = "h-6 w-6 rounded-full border-2 border-white bg-white"
        stack.appendChild(avatar)
      })
      button.appendChild(stack)
      return
    }

    if ((item.avatarPaths || []).length === 1) {
      const avatar = document.createElement("img")
      avatar.src = item.avatarPaths[0]
      avatar.alt = item.name
      avatar.className = "h-6 w-6 rounded-full"
      button.appendChild(avatar)
      return
    }

    if ((item.swatchHexes || []).length > 0) {
      const stack = document.createElement("span")
      stack.className = "flex -space-x-1"
      item.swatchHexes.slice(0, 3).forEach((hex) => {
        const swatch = document.createElement("span")
        swatch.className = "inline-flex h-5 w-5 rounded-full border-2 border-white shadow-xs"
        swatch.style.backgroundColor = hex
        stack.appendChild(swatch)
      })
      button.appendChild(stack)
    }
  }

  renderChart() {
    const series = this.currentSecondaryItems()
      .filter((item) => this.selectedSecondaryIds.has(item.id))
      .map((item) => ({ name: item.name, points: item.points || [] }))

    if (series.length === 0) {
      this.destroyChart()
      this.chartCanvasTarget.classList.add("hidden")
      this.emptyStateTarget.classList.remove("hidden")
      return
    }

    this.chartCanvasTarget.classList.remove("hidden")
    this.emptyStateTarget.classList.add("hidden")
    const labels = this.timelineLabels(series)
    const datasets = series.map((entry, index) => ({
      label: entry.name,
      data: this.monthlySeries(entry.points, labels),
      borderColor: this.palette(index).border,
      backgroundColor: this.palette(index).fill,
      borderWidth: 1,
      borderRadius: 8,
      borderSkipped: false
    }))

    this.destroyChart()
    this.chart = new Chart(this.chartCanvasTarget, this.chartOptions(labels, datasets))
  }

  chartOptions(labels, datasets) {
    return {
      type: "bar",
      data: { labels, datasets },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        datasets: {
          bar: {
            categoryPercentage: 0.7,
            barPercentage: 0.82
          }
        },
        interaction: { mode: "index", intersect: false },
        plugins: {
          legend: {
            position: "top",
            align: "start",
            labels: {
              boxWidth: 12,
              boxHeight: 12,
              color: "#0f172a",
              usePointStyle: true,
              pointStyle: "circle"
            }
          },
          tooltip: {
            callbacks: {
              label: (context) => `${context.dataset.label}: ${this.formatCurrencyFromFloat(context.parsed.y)}`,
              title: (items) => {
                const raw = items[0]?.label
                return raw ? new Intl.DateTimeFormat("pt-BR", { month: "short", year: "numeric" }).format(this.parseISODate(raw)) : ""
              }
            }
          }
        },
        scales: {
          x: {
            ticks: {
              color: "#64748b",
              maxRotation: 0
            },
            grid: { display: false }
          },
          y: {
            ticks: {
              color: "#64748b",
              callback: (value) => this.formatCurrencyFromFloat(value)
            },
            grid: { color: "rgba(148, 163, 184, 0.18)" }
          }
        }
      },
      plugins: [{
        id: "legendBottomPadding",
        beforeInit: (chart) => {
          const originalFit = chart.legend.fit
          chart.legend.fit = function fitWithBottomPadding() {
            originalFit.bind(chart.legend)()
            this.height += 18
          }
        }
      }, {
        id: "chartAreaBackground",
        beforeDraw: (chart) => {
          const { ctx, chartArea } = chart
          if (!chartArea) return

          ctx.save()
          ctx.fillStyle = "#ffffff"
          ctx.fillRect(chartArea.left, chartArea.top, chartArea.right - chartArea.left, chartArea.bottom - chartArea.top)
          ctx.restore()
        }
      }]
    }
  }

  destroyChart() {
    if (this.chart && typeof this.chart.destroy === "function") {
      this.chart.destroy()
      this.chart = null
    }
  }

  currentPrimary() {
    return this.dataValue.items.find((item) => item.id === this.primarySelectTarget.value)
  }

  currentGroups() {
    return this.currentPrimary()?.groups || []
  }

  defaultGroupId() {
    return this.currentGroups().find((group) => group.id === "__all__")?.id || this.currentGroups()[0]?.id
  }

  currentSecondaryItems() {
    const groups = this.currentGroups().filter((group) => this.selectedGroupIds.has(group.id))
    const secondaryItemMap = new Map()

    groups.forEach((group) => {
      ;(group.secondaryItems || []).forEach((item) => {
        const existing = secondaryItemMap.get(item.id)
        if (!existing) {
          secondaryItemMap.set(item.id, {
            ...item,
            points: [ ...(item.points || []) ],
            avatarPaths: [ ...(item.avatarPaths || []) ],
            swatchHexes: [ ...(item.swatchHexes || []) ]
          })
          return
        }

        existing.total += item.total || 0
        const pointMap = new Map(existing.points.map((point) => [point.x, point.y]))
        ;(item.points || []).forEach((point) => {
          pointMap.set(point.x, (pointMap.get(point.x) || 0) + (point.y || 0))
        })
        existing.points = [...pointMap.entries()].sort(([left], [right]) => left.localeCompare(right)).map(([x, y]) => ({ x, y }))
      })
    })

    return [...secondaryItemMap.values()].sort((left, right) => {
      if ((left.rank || 0) !== (right.rank || 0)) return (left.rank || 0) - (right.rank || 0)
      return Math.abs(right.total || 0) - Math.abs(left.total || 0)
    })
  }

  resetSelectedSecondaryItems() {
    this.selectedSecondaryIds = new Set(this.currentSecondaryItems().map((item) => item.id))
  }

  buildActionButton(label, handler, active = false) {
    const button = document.createElement("button")
    button.type = "button"
    button.textContent = label
    button.className = [
      "inline-flex min-h-11 items-center justify-center rounded-sm border px-3 py-2 text-sm font-semibold shadow-sm transition",
      active ? "border-sky-500 bg-sky-100 text-sky-900" : "border-slate-300 bg-white text-slate-700 hover:border-slate-400 hover:bg-slate-100"
    ].join(" ")
    button.addEventListener("click", handler)
    return button
  }

  filterButtonClass(selected) {
    return [
      "inline-flex min-h-11 items-center justify-center rounded-sm border px-3 py-2 text-sm font-semibold shadow-sm transition",
      selected ? "border-sky-500 bg-sky-50 text-sky-950" : "border-slate-300 bg-white text-slate-700 hover:border-slate-400 hover:bg-slate-50"
    ].join(" ")
  }

  secondaryButtonClass(selected) {
    return [
      "inline-flex min-h-12 items-center gap-2 rounded-lg border px-3 py-2 text-left text-sm shadow-sm transition",
      selected ? "border-sky-500 bg-sky-50 text-sky-950" : "border-slate-300 bg-white text-slate-700 hover:border-slate-400 hover:bg-slate-50"
    ].join(" ")
  }

  secondaryTotalClass(selected) {
    return [
      "ml-auto rounded-full px-2 py-1 text-2xs font-black uppercase tracking-[0.16em]",
      selected ? "bg-sky-200 text-sky-950" : "bg-slate-200 text-slate-700"
    ].join(" ")
  }

  formatCurrency(cents) {
    return this.formatCurrencyFromFloat((cents || 0) / 100.0)
  }

  formatCurrencyFromFloat(value) {
    return new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }).format(value || 0)
  }

  timelineLabels(items) {
    const pointDates = items.flatMap((item) => item.points.map((point) => point.x)).sort()
    const earliestPoint = pointDates[0]
    const latestPoint = pointDates[pointDates.length - 1]
    const rangeStart = earliestPoint || this.dataValue.rangeStart || this.isoDate(new Date())
    const rangeEnd = latestPoint || this.dataValue.rangeEnd || this.isoDate(new Date())
    const current = this.startOfMonth(this.parseISODate(rangeStart))
    const end = this.startOfMonth(this.parseISODate(rangeEnd))
    const labels = []

    while (current <= end) {
      labels.push(this.isoDate(current))
      current.setMonth(current.getMonth() + 1)
    }

    return labels
  }

  monthlySeries(points, labels) {
    const totalsByDate = new Map()
    ;(points || []).forEach((point) => {
      const monthKey = this.isoDate(this.startOfMonth(this.parseISODate(point.x)))
      totalsByDate.set(monthKey, (totalsByDate.get(monthKey) || 0) + (point.y / 100.0))
    })

    return labels.map((label) => totalsByDate.get(label) || 0)
  }

  isoDate(date) {
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, "0")
    const day = String(date.getDate()).padStart(2, "0")
    return `${year}-${month}-${day}`
  }

  parseISODate(value) {
    const [year, month, day] = value.split("-").map(Number)
    return new Date(year, month - 1, day)
  }

  startOfMonth(date) {
    return new Date(date.getFullYear(), date.getMonth(), 1)
  }

  palette(index) {
    const colours = [
      { border: "#2563eb", fill: "rgba(37, 99, 235, 0.16)" },
      { border: "#7c3aed", fill: "rgba(124, 58, 237, 0.16)" },
      { border: "#ea580c", fill: "rgba(234, 88, 12, 0.16)" },
      { border: "#0f766e", fill: "rgba(15, 118, 110, 0.16)" },
      { border: "#be123c", fill: "rgba(190, 18, 60, 0.16)" },
      { border: "#0891b2", fill: "rgba(8, 145, 178, 0.16)" }
    ]

    return colours[index % colours.length]
  }
}
