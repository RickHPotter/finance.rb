import { Controller } from "@hotwired/stimulus"
import { ArcElement, Chart, Legend, PieController, Tooltip } from "chart.js"

Chart.register(PieController, ArcElement, Tooltip, Legend)

export default class extends Controller {
  static targets = ["filterInput", "chartCanvas", "emptyState", "legend"]
  static values = { data: Object }

  connect() {
    this.chart = null
    this.render()
  }

  disconnect() {
    this.destroyChart()
  }

  changeFilter() {
    this.render()
  }

  render() {
    const entries = this.filteredEntries()

    this.legendTarget.innerHTML = ""

    if (entries.length === 0) {
      this.destroyChart()
      this.chartCanvasTarget.classList.add("hidden")
      this.emptyStateTarget.classList.remove("hidden")
      return
    }

    this.chartCanvasTarget.classList.remove("hidden")
    this.emptyStateTarget.classList.add("hidden")

    const labels = entries.map((entry) => entry.name)
    const data = entries.map((entry) => entry.total / 100.0)
    const backgroundColor = entries.map((entry, index) => entry.colour || this.palette(index))

    this.renderLegend(entries, backgroundColor)

    this.destroyChart()
    this.chart = new Chart(this.chartCanvasTarget, {
      type: "pie",
      data: {
        labels,
        datasets: [{
          data,
          backgroundColor,
          borderColor: "#ffffff",
          borderWidth: 2
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            callbacks: {
              label: (context) => `${context.label}: ${this.formatCurrencyFromFloat(context.parsed)}`
            }
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
    })
  }

  filteredEntries() {
    const entries = (this.dataValue.entries || []).map((entry) => ({
      ...entry,
      total: this.entryTotal(entry)
    })).filter((entry) => entry.total > 0)

    return entries.sort((left, right) => right.total - left.total)
  }

  entryTotal(entry) {
    if (!this.hasFilterInputTarget) return entry.total || 0

    const selectedSources = this.selectedFilterIds()
    if (selectedSources.length === 0) return 0

    return selectedSources.reduce((sum, sourceId) => sum + Number(entry.totalsBySource?.[sourceId] || 0), 0)
  }

  selectedFilterIds() {
    if (!this.hasFilterInputTarget) return []

    return this.filterInputTargets.filter((input) => input.checked).map((input) => input.value)
  }

  renderLegend(entries, colours) {
    entries.forEach((entry, index) => {
      const row = document.createElement("div")
      row.className = "flex items-center justify-between gap-3 rounded-xl border border-slate-200 bg-white px-3 py-2"

      const left = document.createElement("div")
      left.className = "flex min-w-0 items-center gap-2"

      const dot = document.createElement("span")
      dot.className = "inline-flex h-3 w-3 shrink-0 rounded-full"
      dot.style.backgroundColor = colours[index]
      left.appendChild(dot)

      const name = document.createElement("span")
      name.className = "truncate text-sm font-semibold text-slate-900"
      name.textContent = entry.name
      left.appendChild(name)

      const total = document.createElement("span")
      total.className = "shrink-0 rounded-full bg-slate-100 px-2 py-1 text-2xs font-black uppercase tracking-[0.16em] text-slate-700"
      total.textContent = this.formatCurrency(entry.total)

      row.appendChild(left)
      row.appendChild(total)
      this.legendTarget.appendChild(row)
    })
  }

  destroyChart() {
    if (this.chart && typeof this.chart.destroy === "function") {
      this.chart.destroy()
      this.chart = null
    }
  }

  formatCurrency(cents) {
    return this.formatCurrencyFromFloat((cents || 0) / 100.0)
  }

  formatCurrencyFromFloat(value) {
    return new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }).format(value || 0)
  }

  palette(index) {
    const colours = ["#2563eb", "#ea580c", "#0f766e", "#7c3aed", "#be123c", "#0891b2", "#65a30d", "#f59e0b"]
    return colours[index % colours.length]
  }
}
