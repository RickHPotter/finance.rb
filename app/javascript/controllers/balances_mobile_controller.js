import { Controller } from "@hotwired/stimulus"
import {
  BarController,
  BarElement,
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

Chart.register(LineController, LineElement, PointElement, LinearScale, CategoryScale, BarController, BarElement, Tooltip, Legend, Filler)

const monthlyRangeConnectorPlugin = {
  id: "monthlyRangeConnector",
  afterDatasetsDraw(chart) {
    const highMeta = chart.getDatasetMeta(0)
    const lowMeta = chart.getDatasetMeta(1)
    if (!highMeta?.data?.length || !lowMeta?.data?.length) return

    const { ctx } = chart
    ctx.save()
    ctx.strokeStyle = "rgba(120, 113, 108, 0.35)"
    ctx.lineWidth = 2

    highMeta.data.forEach((highPoint, index) => {
      const lowPoint = lowMeta.data[index]
      if (!highPoint || !lowPoint) return

      ctx.beginPath()
      ctx.moveTo(highPoint.x, highPoint.y)
      ctx.lineTo(lowPoint.x, lowPoint.y)
      ctx.stroke()
    })

    ctx.restore()
  }
}

export default class extends Controller {
  static values = { summaryUrl: String, trendUrl: String, breakdownUrl: String }
  static targets = [
    "trendCanvas",
    "extremesCanvas",
    "breakdownCanvas",
    "monthInput",
    "legend",
    "presetButton",
    "rangeButton",
    "currentValue",
    "highValue",
    "lowValue"
  ]

  async connect() {
    this.preset = "from_now"
    this.range = "1y"
    this.summary = null
    this.trendChart = null
    this.extremesChart = null
    this.breakdownChart = null

    await this.loadSummary()
    await this.loadTrend()
    await this.loadBreakdown()
  }

  disconnect() {
    this.trendChart?.destroy()
    this.extremesChart?.destroy()
    this.breakdownChart?.destroy()
  }

  async changePreset(event) {
    this.preset = event.currentTarget.dataset.preset
    this.presetButtonTargets.forEach((button) => {
      const selected = button.dataset.preset === this.preset
      button.className = selected ?
        "inline-flex items-center rounded-full border px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.16em] transition border-sky-700 bg-sky-700 text-white" :
        "inline-flex items-center rounded-full border px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.16em] transition border-stone-200 bg-white text-stone-600"
    })

    this.renderTrend()
  }

  async changeRange(event) {
    this.range = event.currentTarget.dataset.range
    this.rangeButtonTargets.forEach((button) => {
      const selected = button.dataset.range === this.range
      button.className = selected ?
        "inline-flex items-center rounded-full border px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.16em] transition border-stone-900 bg-stone-900 text-white" :
        "inline-flex items-center rounded-full border px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.16em] transition border-stone-200 bg-white text-stone-600"
    })

    this.renderTrend()
  }

  async changeMonth() {
    await this.loadBreakdown()
  }

  async loadSummary() {
    const response = await fetch(this.summaryUrlValue)
    this.summary = await response.json()
  }

  async loadTrend() {
    const response = await fetch(this.trendUrlValue)
    this.trendData = await response.json()
    this.renderTrend()
  }

  async loadBreakdown() {
    const month = this.monthInputTarget.value
    const url = new URL(this.breakdownUrlValue, window.location.origin)
    url.searchParams.set("month_year_one", `${month}-01`)
    url.searchParams.set("month_year_two", `${month}-01`)

    const response = await fetch(url)
    this.breakdownData = await response.json()
    this.renderBreakdown()
  }

  renderTrend() {
    if (!this.trendData?.length) return

    const filtered = this.filteredTrendData()
    const labels = filtered.map((point) => point.label)
    const values = filtered.map((point) => point.y)
    const high = Math.max(...values)
    const low = Math.min(...values)
    const currentFilteredIndex = filtered.findIndex((point) => point.raw_month_year === this.summary?.current_month_year)
    const currentValue = this.summary?.current_value ?? 0

    this.currentValueTarget.textContent = this.currency(currentValue)
    this.highValueTarget.textContent = this.currency(high)
    this.lowValueTarget.textContent = this.currency(low)
    this.applyValueTone(this.currentValueTarget, currentValue)
    this.applyValueTone(this.highValueTarget, high)
    this.applyValueTone(this.lowValueTarget, low)

    this.trendChart?.destroy()
    this.trendChart = new Chart(this.trendCanvasTarget, {
      type: "line",
      data: {
        labels,
        datasets: [
          {
            data: values,
            borderColor: "#0f766e",
            backgroundColor: "rgba(15, 118, 110, 0.15)",
            fill: true,
            tension: 0.35,
            pointRadius: filtered.map((_, index) => (index === currentFilteredIndex ? 4 : 0)),
            pointHoverRadius: filtered.map((_, index) => (index === currentFilteredIndex ? 6 : 4)),
            pointHitRadius: 20,
            pointBackgroundColor: filtered.map((_, index) => (index === currentFilteredIndex ? "#2563eb" : "#0f766e")),
            pointBorderColor: filtered.map((_, index) => (index === currentFilteredIndex ? "#ffffff" : "#0f766e")),
            pointBorderWidth: filtered.map((_, index) => (index === currentFilteredIndex ? 2 : 0)),
            borderWidth: 3
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: { mode: "index", intersect: false },
        plugins: {
          legend: { display: false },
          tooltip: {
            displayColors: false,
            callbacks: {
              label: (context) => this.currency(context.parsed.y)
            }
          }
        },
        scales: {
          x: {
            ticks: {
              color: "#57534e",
              maxRotation: 0,
              autoSkip: true,
              maxTicksLimit: 6
            },
            grid: { display: false }
          },
          y: {
            ticks: {
              color: "#57534e",
              callback: (value) => this.currencyShort(value)
            },
            grid: { color: "rgba(120, 113, 108, 0.12)" }
          }
        }
      }
    })

    this.renderExtremes(filtered)
  }

  renderExtremes(filtered) {
    const grouped = filtered.reduce((acc, point) => {
      if (!acc[point.raw_month_year]) {
        acc[point.raw_month_year] = { label: point.label, values: [] }
      }

      acc[point.raw_month_year].values.push(point.y)
      return acc
    }, {})

    const monthlyExtremes = Object.entries(grouped)
      .sort(([left], [right]) => Number(left) - Number(right))
      .map(([, data]) => ({
        label: data.label,
        high: Math.max(...data.values),
        low: Math.min(...data.values)
      }))

    this.extremesChart?.destroy()
    this.extremesChart = new Chart(this.extremesCanvasTarget, {
      type: "line",
      plugins: [monthlyRangeConnectorPlugin],
      data: {
        labels: monthlyExtremes.map((point) => point.label),
        datasets: [
          {
            label: this.extremesCanvasTarget.dataset.highLabel || "High",
            data: monthlyExtremes.map((point) => point.high),
            borderColor: "#0f766e",
            backgroundColor: "rgba(15, 118, 110, 0.12)",
            tension: 0.35,
            pointRadius: 4,
            pointHoverRadius: 6,
            pointHitRadius: 20,
            pointBackgroundColor: "#0f766e",
            borderWidth: 3,
            fill: false
          },
          {
            label: this.extremesCanvasTarget.dataset.lowLabel || "Low",
            data: monthlyExtremes.map((point) => point.low),
            borderColor: "#dc2626",
            backgroundColor: "rgba(220, 38, 38, 0.12)",
            tension: 0.35,
            pointRadius: 4,
            pointHoverRadius: 6,
            pointHitRadius: 20,
            pointBackgroundColor: "#dc2626",
            borderWidth: 3,
            fill: false
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: { mode: "index", intersect: false },
        plugins: {
          legend: {
            display: true,
            position: "bottom",
            labels: {
              usePointStyle: true,
              boxWidth: 10,
              color: "#57534e"
            }
          },
          tooltip: {
            displayColors: true,
            callbacks: {
              label: (context) => `${context.dataset.label}: ${this.currency(context.parsed.y)}`
            }
          }
        },
        scales: {
          x: {
            ticks: {
              color: "#57534e",
              maxRotation: 0,
              autoSkip: true,
              maxTicksLimit: 6
            },
            grid: { display: false }
          },
          y: {
            ticks: {
              color: "#57534e",
              callback: (value) => this.currencyShort(value)
            },
            grid: { color: "rgba(120, 113, 108, 0.12)" }
          }
        }
      }
    })
  }

  renderBreakdown() {
    const sorted = [...(this.breakdownData || [])]
      .sort((a, b) => Math.abs(b.price) - Math.abs(a.price))
      .slice(0, 6)

    const labels = sorted.map((item) => item.category_name)
    const values = sorted.map((item) => Math.abs(item.price))
    const colors = sorted.map((item) => item.color || "#a8a29e")

    this.legendTarget.innerHTML = ""
    sorted.forEach((item) => {
      const row = document.createElement("div")
      row.className = "flex items-center justify-between rounded-2xl border border-stone-200 bg-stone-50 px-3 py-2 text-sm"
      row.innerHTML = `
        <div class="flex items-center gap-2 min-w-0">
          <span class="inline-flex size-3 rounded-full shrink-0" style="background:${item.color || "#a8a29e"}"></span>
          <span class="truncate text-stone-700">${item.category_name}</span>
        </div>
        <span class="shrink-0 font-semibold text-stone-900">${this.currency(item.price)}</span>
      `
      this.legendTarget.appendChild(row)
    })

    this.breakdownChart?.destroy()
    this.breakdownChart = new Chart(this.breakdownCanvasTarget, {
      type: "bar",
      data: {
        labels,
        datasets: [
          {
            data: values,
            backgroundColor: colors,
            borderRadius: 10,
            borderSkipped: false
          }
        ]
      },
      options: {
        indexAxis: "y",
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            displayColors: false,
            callbacks: {
              label: (context) => this.currency(context.raw)
            }
          }
        },
        scales: {
          x: {
            ticks: {
              color: "#57534e",
              callback: (value) => this.currencyShort(value)
            },
            grid: { color: "rgba(120, 113, 108, 0.12)" }
          },
          y: {
            ticks: {
              color: "#57534e"
            },
            grid: { display: false }
          }
        }
      }
    })
  }

  filteredTrendData() {
    const sorted = [...(this.trendData || [])].sort((a, b) => a.raw_month_year - b.raw_month_year)
    if (!sorted.length) return sorted

    if (this.range === "all") {
      if (this.preset === "from_now") return sorted.filter((point) => point.raw_month_year >= this.currentYearMonth())
      if (this.preset === "until_now") return sorted.filter((point) => point.raw_month_year <= this.currentYearMonth())

      return sorted
    }

    const months = this.range === "3m" ? 3 : (this.range === "6m" ? 6 : 12)
    const currentDate = this.currentMonthDate()
    let startDate = currentDate
    let endDate = currentDate

    if (this.preset === "from_now") {
      endDate = this.addMonths(currentDate, months - 1)
    } else if (this.preset === "until_now") {
      startDate = this.addMonths(currentDate, -(months - 1))
    } else {
      const beforeCount = Math.floor(months / 2)
      const afterCount = months - beforeCount - 1
      startDate = this.addMonths(currentDate, -beforeCount)
      endDate = this.addMonths(currentDate, afterCount)
    }

    const startYm = this.yearMonthFromDate(startDate)
    const endYm = this.yearMonthFromDate(endDate)

    return sorted.filter((point) => point.raw_month_year >= startYm && point.raw_month_year <= endYm)
  }

  currentMonthDate() {
    const now = new Date()
    return new Date(now.getFullYear(), now.getMonth(), 1)
  }

  currentYearMonth() {
    return this.yearMonthFromDate(this.currentMonthDate())
  }

  yearMonthFromDate(date) {
    return date.getFullYear() * 100 + date.getMonth() + 1
  }

  addMonths(date, count) {
    return new Date(date.getFullYear(), date.getMonth() + count, 1)
  }

  currency(value) {
    return new Intl.NumberFormat("pt-BR", {
      style: "currency",
      currency: "BRL"
    }).format(value || 0)
  }

  currencyShort(value) {
    const formatted = this.currency(value || 0)
    return formatted.replace(",00", "")
  }

  applyValueTone(target, value) {
    target.classList.remove("text-stone-900", "text-emerald-700", "text-red-700")

    if (value > 0) {
      target.classList.add("text-emerald-700")
    } else if (value < 0) {
      target.classList.add("text-red-700")
    } else {
      target.classList.add("text-stone-900")
    }
  }
}
