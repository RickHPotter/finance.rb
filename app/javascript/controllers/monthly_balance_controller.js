import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

export default class extends Controller {
  static targets = ["canvas", "preset", "slider", "sliderLabel"]
  static values = { url: String }

  connect() {
    fetch(this.urlValue)
      .then(r => r.json())
      .then(data => {
        this.rawData = data.map((d, index) => ({ ...d }))
        this.render()
      })
  }

  updateFilter({ currentTarget }) {
    if (currentTarget === this.sliderTarget && this.sliderTarget.value > 0) {
      this.presetTarget.value = "custom"
    } else {
      this.sliderTarget.value = 0
      this.sliderLabelTarget.textContent = `0%`
    }

    this.render()
  }

  render() {
    const preset = this.presetTarget?.value || "all"
    const now = new Date()
    const currentYm = now.getFullYear() * 100 + now.getMonth() + 1

    let filtered = this.rawData

    if (preset === "from_now") {
      filtered = this.rawData.filter(d => parseInt(d.raw_month_year) >= currentYm)
    } else if (preset === "until_now") {
      filtered = this.rawData.filter(d => parseInt(d.raw_month_year) <= currentYm)
    } else if (preset === "around_now") {
      const from = currentYm - 3
      const to = currentYm + 3
      filtered = this.rawData.filter(d => {
        const ym = parseInt(d.raw_month_year)
        return ym >= from && ym <= to
      })
    } else if (preset === "custom") {
      const percent = parseInt(this.sliderTarget.value)
      const startIndex = Math.floor((percent / 100) * this.rawData.length)
      this.sliderLabelTarget.textContent = `${percent}%`
      filtered = this.rawData.slice(startIndex)
    }

    const labels = filtered.map(p => p.label)
    const balances = filtered.map(p => p.y)

    const max = Math.max(...balances)
    const min = Math.min(...balances)

    const pointColors = balances.map(val => {
      if (val === max) return "rgba(0, 200, 80, 1)"
      if (val === min) return "rgba(255, 80, 80, 1)"
      return "rgba(0, 180, 200, 1)"
    })

    if (this.chart) this.chart.destroy()

    this.chart = new Chart(this.canvasTarget, {
      type: "line",
      data: {
        labels: labels,
        datasets: [{
          label: "Balance",
          data: balances,
          borderColor: "rgba(0, 180, 200, 1)",
          backgroundColor: "rgba(0, 180, 200, 0.1)",
          pointRadius: 3,
          pointHoverRadius: 6,
          tension: 0.3,
          fill: true,
          pointBackgroundColor: pointColors
        }]
      },
      options: {
        responsive: true,
        plugins: {
          tooltip: {
            callbacks: {
              label: ctx => `R$ ${(ctx.parsed.y).toLocaleString("pt-BR", { minimumFractionDigits: 2 })}`
            }
          }
        },
        scales: {
          x: {
            ticks: {
              maxRotation: 60,
              minRotation: 30
            }
          },
          y: {
            ticks: {
              callback: val => "R$ " + val.toLocaleString("pt-BR")
            }
          }
        }
      }
    })
  }
}
