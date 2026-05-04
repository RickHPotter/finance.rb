import { Controller } from "@hotwired/stimulus"
import {
  CategoryScale,
  Chart,
  Filler,
  Legend,
  LineController,
  LineElement,
  LinearScale,
  PointElement,
  Tooltip
} from "chart.js"

Chart.register(LineController, LineElement, PointElement, LinearScale, CategoryScale, Tooltip, Legend, Filler)

export default class extends Controller {
  static targets = ["categorySelect", "categoryGroupActions", "categoryGroupOptions", "entityActions", "entityOptions", "chartCanvas", "emptyState"]
  static values = { data: Object }

  connect() {
    this.selectedGroupIds = new Set()
    this.selectedEntityIds = new Set()
    this.chart = null
    this.renderCurrentCategory()
  }

  disconnect() {
    this.destroyChart()
  }

  changeCategory() {
    this.renderCurrentCategory()
  }

  selectAllGroups() {
    this.selectedGroupIds = new Set(this.currentGroups().map((group) => group.id))
    this.renderCategoryGroupToolbar()
    this.resetSelectedEntities()
    this.renderEntityToolbar()
    this.renderChart()
  }

  unselectAllGroups() {
    this.selectedGroupIds = new Set()
    this.renderCategoryGroupToolbar()
    this.resetSelectedEntities()
    this.renderEntityToolbar()
    this.renderChart()
  }

  toggleGroup(event) {
    const { groupId } = event.currentTarget.dataset
    if (!groupId) return

    if (this.selectedGroupIds.has(groupId)) {
      this.selectedGroupIds.delete(groupId)
    } else {
      this.selectedGroupIds.add(groupId)
    }

    this.renderCategoryGroupToolbar()
    this.resetSelectedEntities()
    this.renderEntityToolbar()
    this.renderChart()
  }

  selectAll() {
    this.selectedEntityIds = new Set(this.currentEntities().map((entity) => entity.id))
    this.renderEntityToolbar()
    this.renderChart()
  }

  unselectAll() {
    this.selectedEntityIds = new Set()
    this.renderEntityToolbar()
    this.renderChart()
  }

  toggleEntity(event) {
    const { entityId } = event.currentTarget.dataset
    if (!entityId) return

    if (this.selectedEntityIds.has(entityId)) {
      this.selectedEntityIds.delete(entityId)
    } else {
      this.selectedEntityIds.add(entityId)
    }

    this.renderEntityToolbar()
    this.renderChart()
  }

  renderCurrentCategory() {
    this.selectedGroupIds = new Set([this.defaultGroupId()])
    this.renderCategoryGroupToolbar()
    this.resetSelectedEntities()
    this.renderEntityToolbar()
    this.renderChart()
  }

  renderCategoryGroupToolbar() {
    const groups = this.currentGroups()
    this.categoryGroupActionsTarget.innerHTML = ""
    this.categoryGroupOptionsTarget.innerHTML = ""

    this.categoryGroupActionsTarget.appendChild(
      this.buildActionButton("Select All", () => this.selectAllGroups(), this.selectedGroupIds.size === groups.length && groups.length > 0)
    )
    this.categoryGroupActionsTarget.appendChild(
      this.buildActionButton("Unselect All", () => this.unselectAllGroups(), this.selectedGroupIds.size === 0)
    )

    groups.forEach((group) => {
      const button = document.createElement("button")
      button.type = "button"
      button.dataset.groupId = group.id
      button.addEventListener("click", (event) => this.toggleGroup(event))
      button.className = this.filterButtonClass(this.selectedGroupIds.has(group.id))
      button.textContent = group.label
      this.categoryGroupOptionsTarget.appendChild(button)
    })
  }

  renderEntityToolbar() {
    const entities = this.currentEntities()
    this.entityActionsTarget.innerHTML = ""
    this.entityOptionsTarget.innerHTML = ""

    this.entityActionsTarget.appendChild(
      this.buildActionButton("Select All", () => this.selectAll(), this.selectedEntityIds.size === entities.length && entities.length > 0)
    )
    this.entityActionsTarget.appendChild(
      this.buildActionButton("Unselect All", () => this.unselectAll(), this.selectedEntityIds.size === 0)
    )

    entities.forEach((entity) => {
      const button = document.createElement("button")
      button.type = "button"
      button.dataset.entityId = entity.id
      button.addEventListener("click", (event) => this.toggleEntity(event))
      button.className = this.entityButtonClass(this.selectedEntityIds.has(entity.id))

      if ((entity.avatarPaths || []).length > 1) {
        const stack = document.createElement("span")
        stack.className = "flex -space-x-2"
        entity.avatarPaths.slice(0, 3).forEach((avatarPath) => {
          const avatar = document.createElement("img")
          avatar.src = avatarPath
          avatar.alt = entity.name
          avatar.className = "h-6 w-6 rounded-full border-2 border-white bg-white"
          stack.appendChild(avatar)
        })
        button.appendChild(stack)
      } else if ((entity.avatarPaths || []).length === 1) {
        const avatar = document.createElement("img")
        avatar.src = entity.avatarPaths[0]
        avatar.alt = entity.name
        avatar.className = "h-6 w-6 rounded-full"
        button.appendChild(avatar)
      }

      const name = document.createElement("span")
      name.className = "break-words"
      name.textContent = entity.name
      button.appendChild(name)

      const total = document.createElement("span")
      total.className = this.entityTotalClass(this.selectedEntityIds.has(entity.id))
      total.textContent = this.formatCurrency(entity.total)
      button.appendChild(total)

      this.entityOptionsTarget.appendChild(button)
    })
  }

  renderChart() {
    const series = this.currentEntities().filter((entity) => this.selectedEntityIds.has(entity.id)).map((entity) => ({ name: entity.name, points: entity.points || [] }))
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
      fill: true,
      tension: 0.35,
      pointRadius: 3,
      pointHoverRadius: 5,
      pointHitRadius: 16,
      borderWidth: 2
    }))

    this.destroyChart()
    this.chart = new Chart(this.chartCanvasTarget, this.chartOptions(labels, datasets))
  }

  chartOptions(labels, datasets) {
    return {
      type: "line",
      data: { labels, datasets },
      options: {
        responsive: true,
        maintainAspectRatio: false,
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
                return raw ? new Intl.DateTimeFormat("pt-BR", { month: "short", year: "numeric" }).format(new Date(raw)) : ""
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

  currentCategory() {
    return this.dataValue.categories.find((category) => category.id === this.categorySelectTarget.value)
  }

  currentGroups() {
    return this.currentCategory()?.groups || []
  }

  defaultGroupId() {
    return this.currentGroups().find((group) => group.id === "__all__")?.id || this.currentGroups()[0]?.id
  }

  currentEntities() {
    const groups = this.currentGroups().filter((group) => this.selectedGroupIds.has(group.id))
    const entityMap = new Map()

    groups.forEach((group) => {
      ;(group.entities || []).forEach((entity) => {
        const existing = entityMap.get(entity.id)
        if (!existing) {
          entityMap.set(entity.id, {
            ...entity,
            points: [ ...(entity.points || []) ],
            avatarPaths: [ ...(entity.avatarPaths || []) ]
          })
          return
        }

        existing.total += entity.total || 0
        const pointMap = new Map(existing.points.map((point) => [point.x, point.y]))
        ;(entity.points || []).forEach((point) => {
          pointMap.set(point.x, (pointMap.get(point.x) || 0) + (point.y || 0))
        })
        existing.points = [...pointMap.entries()].sort(([left], [right]) => left.localeCompare(right)).map(([x, y]) => ({ x, y }))
      })
    })

    return [...entityMap.values()].sort((left, right) => {
      if ((left.rank || 0) !== (right.rank || 0)) return (left.rank || 0) - (right.rank || 0)
      return Math.abs(right.total || 0) - Math.abs(left.total || 0)
    })
  }

  resetSelectedEntities() {
    this.selectedEntityIds = new Set(this.currentEntities().map((entity) => entity.id))
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

  entityButtonClass(selected) {
    return [
      "inline-flex min-h-12 items-center gap-2 rounded-lg border px-3 py-2 text-left text-sm shadow-sm transition",
      selected ? "border-sky-500 bg-sky-50 text-sky-950" : "border-slate-300 bg-white text-slate-700 hover:border-slate-400 hover:bg-slate-50"
    ].join(" ")
  }

  entityTotalClass(selected) {
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

  timelineLabels(entities) {
    const earliestPoint = entities.flatMap((entity) => entity.points.map((point) => point.x)).sort()[0]
    const rangeStart = this.dataValue.rangeStart || earliestPoint || this.isoDate(new Date())
    const current = this.startOfMonth(new Date(rangeStart))
    const end = this.startOfMonth(new Date())
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
      const monthKey = this.isoDate(this.startOfMonth(new Date(point.x)))
      totalsByDate.set(monthKey, (totalsByDate.get(monthKey) || 0) + (point.y / 100.0))
    })

    return labels.map((label) => totalsByDate.get(label) || 0)
  }

  isoDate(date) {
    return date.toISOString().slice(0, 10)
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
