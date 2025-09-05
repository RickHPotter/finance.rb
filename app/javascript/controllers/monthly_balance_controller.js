import { Controller } from "@hotwired/stimulus"
import ApexCharts from "apexcharts"

export default class extends Controller {
  static targets = ["chart", "preset"]
  static values = { url: String }

  connect() {
    this.isTouch = "ontouchstart" in document.documentElement

    fetch(this.urlValue)
      .then(r => r.json())
      .then(data => {
        this.rawData = data.map(d => ({ ...d }))
        this.render()
      })
  }

  render() {
    const preset = this.presetTarget?.value || "from_now"
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
    }

    let trueMaxPoint = null
    let trueMinPoint = null

    if (filtered.length > 0) {
      trueMaxPoint = filtered.reduce((prev, current) => (prev.y > current.y) ? prev : current)
      trueMinPoint = filtered.reduce((prev, current) => (prev.y < current.y) ? prev : current)
    }

    let finalData = []
    if (filtered.length > 250) {
      const groupedByMonth = filtered.reduce((acc, curr) => {
        (acc[curr.raw_month_year] = acc[curr.raw_month_year] || []).push(curr)
        return acc
      }, {})

      for (const monthYear in groupedByMonth) {
        const monthData = groupedByMonth[monthYear]
        if (monthData.length > 0) {
          const firstPoint = monthData[0]
          const lastPoint = monthData[monthData.length - 1]
          let highestInMonth = monthData[0]
          let lowestInMonth = monthData[0]

          monthData.forEach(point => {
            if (point.y > highestInMonth.y) {
              highestInMonth = point
            }
            if (point.y < lowestInMonth.y) {
              lowestInMonth = point
            }
          })

          finalData.push(firstPoint)

          if (lowestInMonth.x !== firstPoint.x && lowestInMonth.x !== lastPoint.x && highestInMonth.x !== lowestInMonth.x) {
            finalData.push(lowestInMonth)
          }

          if (highestInMonth.x !== firstPoint.x && highestInMonth.x !== lastPoint.x && highestInMonth.x !== lowestInMonth.x) {
            finalData.push(highestInMonth)
          }

          finalData.push(lastPoint)
        }
      }
    } else {
      finalData = filtered
    }

    finalData.sort((a, b) => {
      const aDate = new Date(a.raw_month_year.toString().slice(0, 4), parseInt(a.raw_month_year.toString().slice(4)) - 1)
      const bDate = new Date(b.raw_month_year.toString().slice(0, 4), parseInt(b.raw_month_year.toString().slice(4)) - 1)
      return aDate - bDate
    })

    const defaultMarkerColour = "#0B00F0"
    const highestMarketColour = "#228B22"
    const lowestMarketColour  = "#F00F50"

    const highestPointIndex = finalData.findIndex(p => p.y === trueMaxPoint.y && p.raw_month_year === trueMaxPoint.raw_month_year);
    const lowestPointIndex = finalData.findIndex(p => p.y === trueMinPoint.y && p.raw_month_year === trueMinPoint.raw_month_year);

    const seriesData = finalData.map((p, i) => {
      return { x: i, y: p.y }
    })

    if (this.chart) this.chart.destroy()

    const options = {
      chart: {
        type: "area",
        height: this.chartTarget.offsetHeight,
        toolbar: {
          show: true,
          tools: {
            download: true,
            selection: true,
            zoom: !this.isTouch,
            zoomin: true,
            zoomout: true,
            pan: true,
            reset: true
          }
        }
      },
      dataLabels: {
        enabled: true,
        offsetY: -12,
        style: {
          fontSize: '8px',
          colors: ['#444444']
        },
      },
      colors: ['#444444'],
      series: [{
        name: this.chartTarget.dataset.subtitle,
        data: seriesData
      }],
      xaxis: {
        type: "category",
        categories: finalData.map(p => p.label)
      },
      yaxis: {
        labels: { show: false }
      },
      markers: {
        size: 5,
        colors: [defaultMarkerColour],
        strokeColors: "#FFF",
        shape: "circle",
        discrete: [
          {
            seriesIndex: 0,
            dataPointIndex: highestPointIndex,
            fillColor: highestMarketColour,
            strokeColor: "#FFF",
            size: 5,
            shape: "circle"
          },
          {
            seriesIndex: 0,
            dataPointIndex: lowestPointIndex,
            fillColor: lowestMarketColour,
            strokeColor: "#FFF",
            size: 5,
            shape: "circle"
          }
        ]
      },
      stroke: { curve: "smooth", width: 2 },
      tooltip: {
        x: {
          formatter: (val, { dataPointIndex }) => {
            return finalData[dataPointIndex].label
          }
        },
        y: {
          formatter: val => `R$ ${val.toLocaleString("pt-BR", { minimumFractionDigits: 2 })}`
        }
      },
    }

    this.chart = new ApexCharts(this.chartTarget, options)
    this.chart.render()
  }
}
