import { Controller } from "@hotwired/stimulus"
import ApexCharts from "apexcharts"

export default class extends Controller {
  static values = { url: String, urlTwo: String }
  static targets = [
    "preset", "chartType",
    "pieRealm",
    "monthInput",
    "chart", "negativePieChart", "positivePieChart", "negativeTransactionsPieChart", "positiveTransactionsPieChart"
  ]

  connect() {
    this.isTouch = "ontouchstart" in document.documentElement
    this.currentMonth = new Date().getFullYear() * 100 + (new Date().getMonth() + 1)

    this.monthInputTarget.value = new Date().toISOString().slice(0, 7)
    this.monthInputTarget.addEventListener("change", (e) => {
      const [year, month] = e.target.value.split("-").map(Number)
      this.currentMonth = year * 100 + month
      this.renderMonthCharts()
    })

    fetch(this.urlValue)
      .then(r => r.json())
      .then(data => {
        this.rawData = data.map(d => ({ ...d }))
        this.rerender()
      })
  }

  getFilteredData(preset) {
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
    return filtered
  }

  rerender() {
    if (this.chart) { this.chart.destroy() }
    if (this.negativePieChart) { this.negativePieChart.destroy() }
    if (this.positivePieChart) { this.positivePieChart.destroy() }
    if (this.negativeTransactionsPieChart) { this.negativeTransactionsPieChart.destroy() }
    if (this.positiveTransactionsPieChart) { this.positiveTransactionsPieChart.destroy() }

    this.pieRealmTarget.classList.add("hidden")

    switch (this.chartTypeTarget.value) {
      case "default":
        this.renderDefault()
        break

      case "high_and_low":
      this.renderHighAndLow()
        break

      case "month":
        this.pieRealmTarget.classList.remove("hidden")
        this.renderMonthCharts()
        break

      default:
        break
    }
  }

  prevMonth() {
    let year = Math.floor(this.currentMonth / 100)
    let month = this.currentMonth % 100
    month--
    if (month < 1) {
      month = 12
      year--
    }
    this.currentMonth = year * 100 + month
    this.renderMonthCharts()
  }

  nextMonth() {
    let year = Math.floor(this.currentMonth / 100)
    let month = this.currentMonth % 100
    month++
    if (month > 12) {
      month = 1
      year++
    }
    this.currentMonth = year * 100 + month
    this.renderMonthCharts()
  }

  renderDefault() {
    const filtered = this.getFilteredData(this.presetTarget.value)

    let trueMaxPoint = null
    let trueMinPoint = null

    if (filtered.length > 0) {
      trueMaxPoint = filtered.reduce((prev, current) => (prev.y > current.y) ? prev : current)
      trueMinPoint = filtered.reduce((prev, current) => (prev.y < current.y) ? prev : current)
    }

    filtered.sort((a, b) => {
      const aDate = new Date(a.raw_month_year.toString().slice(0, 4), parseInt(a.raw_month_year.toString().slice(4)) - 1)
      const bDate = new Date(b.raw_month_year.toString().slice(0, 4), parseInt(b.raw_month_year.toString().slice(4)) - 1)
      return aDate - bDate
    })

    const defaultMarkerColour = "#0B00F0"
    const highestMarketColour = "#228B22"
    const lowestMarketColour  = "#F00F50"

    const highestPointIndex = filtered.findIndex(p => p.y === trueMaxPoint.y && p.raw_month_year === trueMaxPoint.raw_month_year)
    const lowestPointIndex = filtered.findIndex(p => p.y === trueMinPoint.y && p.raw_month_year === trueMinPoint.raw_month_year)

    const seriesData = filtered.map((p, i) => {
      return { x: i, y: p.y }
    })

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
      dataLabels: { enabled: false, },
      colors: ["#444444"],
      series: [{
        name: this.chartTarget.dataset.defaultTitle,
        data: seriesData
      }],
      xaxis: {
        type: "category",
        categories: filtered.map(p => p.label)
      },
      yaxis: {
        labels: { show: false, formatter: val => `R$ ${val.toLocaleString("pt-BR", { minimumFractionDigits: 2 })}` }
      },
      markers: {
        size: 3,
        colors: [defaultMarkerColour],
        strokeColors: "#FFF",
        shape: "circle",
        discrete: [
          {
            seriesIndex: 0,
            dataPointIndex: highestPointIndex,
            fillColor: highestMarketColour,
            strokeColor: "#FFF",
            size: 3,
            shape: "circle"
          },
          {
            seriesIndex: 0,
            dataPointIndex: lowestPointIndex,
            fillColor: lowestMarketColour,
            strokeColor: "#FFF",
            size: 3,
            shape: "circle"
          }
        ]
      },
      stroke: { curve: "smooth", width: 2 },
      tooltip: {
        x: {
          formatter: (val, { dataPointIndex }) => {
            return filtered[dataPointIndex].label
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

  renderHighAndLow() {
    const filtered = this.getFilteredData(this.presetTarget.value)

    let trueMaxPoint = null
    let trueMinPoint = null

    if (filtered.length > 0) {
      trueMaxPoint = filtered.reduce((prev, current) => (prev.y > current.y) ? prev : current)
      trueMinPoint = filtered.reduce((prev, current) => (prev.y < current.y) ? prev : current)
    }

    let highData = []
    let lowData = []

    if (filtered.length > 250) {
      const groupedByMonth = filtered.reduce((acc, curr) => {
        (acc[curr.raw_month_year] = acc[curr.raw_month_year] || []).push(curr)
        return acc
      }, {})

      for (const monthYear in groupedByMonth) {
        const monthData = groupedByMonth[monthYear]
        if (monthData.length > 0) {
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

          highData.push(highestInMonth)
          lowData.push(lowestInMonth)
        }
      }
    } else {
      highData = filtered
      lowData = filtered
    }

    highData.sort((a, b) => {
      const aDate = new Date(a.raw_month_year.toString().slice(0, 4), parseInt(a.raw_month_year.toString().slice(4)) - 1)
      const bDate = new Date(b.raw_month_year.toString().slice(0, 4), parseInt(b.raw_month_year.toString().slice(4)) - 1)
      return aDate - bDate
    })

    lowData.sort((a, b) => {
      const aDate = new Date(a.raw_month_year.toString().slice(0, 4), parseInt(a.raw_month_year.toString().slice(4)) - 1)
      const bDate = new Date(b.raw_month_year.toString().slice(0, 4), parseInt(b.raw_month_year.toString().slice(4)) - 1)
      return aDate - bDate
    })

    const highSeriesData = highData.map((p, i) => ({ x: i, y: p.y }))
    const lowSeriesData = lowData.map((p, i) => ({ x: i, y: p.y }))

    const labels = highData.map(p => p.label)

    const defaultMarkerColour = "#555555"
    const highestMarketColour = "#00E500"
    const lowestMarketColour  = "#FF0000"

    const highestPointIndex = highSeriesData.findIndex(p => p.y === trueMaxPoint.y)
    const lowestPointIndex = lowSeriesData.findIndex(p => p.y === trueMinPoint.y)

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
        enabled: false,
        style: {
          fontSize: "12px",
          colors: ["#444444"]
        },
      },
      series: [{
        name: this.chartTarget.dataset.highTitle,
        data: highSeriesData,
      }, {
        name: this.chartTarget.dataset.lowTitle,
        data: lowSeriesData,
      }],
      colors: [highestMarketColour, lowestMarketColour],
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
            seriesIndex: 1,
            dataPointIndex: lowestPointIndex,
            fillColor: lowestMarketColour,
            strokeColor: "#FFF",
            size: 5,
            shape: "circle"
          }
        ]
      },
      xaxis: {
        type: "category",
        categories: labels.slice(1),
      },
      yaxis: {
        labels: { show: false }
      },
      tooltip: {
        x: {
          formatter: (val, { dataPointIndex }) => {
            return highData[dataPointIndex].label
          }
        },
        y: {
          formatter: val => `R$ ${val.toLocaleString("pt-BR", { minimumFractionDigits: 2 })}`
        }
      },
      stroke: { curve: "smooth", width: 2 },
    }

    this.chart = new ApexCharts(this.chartTarget, options)
    this.chart.render()
  }

  renderMonthCharts() {
    const month = this.currentMonth
    const monthData = this.rawData.filter(d => parseInt(d.raw_month_year) === month)

    const year = Math.floor(this.currentMonth / 100)
    const monthIndex = this.currentMonth % 100 - 1
    this.monthInputTarget.value = `${year}-${String(monthIndex + 1).padStart(2, "0")}`

    const areaOptions = {
      chart: {
        type: "bar",
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
      plotOptions: {
        bar: {
          borderRadius: 4,
          borderRadiusApplication: 'end',
          horizontal: true,
        },
      },
      stroke: { curve: "smooth", width: 2 },
      markers: {
        size: 5,
        colors: "#0B00F0",
        strokeColors: "#FFF",
        shape: "circle",
      },
      series: [{
        name: this.chartTarget.dataset.defaultTitle,
        data: monthData.map(d => d.y),
      }],
      yaxis: {
        labels: { show: false }
      },
      dataLabels: { enabled: false },
      tooltip: {
        y: {
          formatter: val => `R$ ${val.toLocaleString("pt-BR", { minimumFractionDigits: 2 })}`
        }
      }
    }
    this.chart = new ApexCharts(this.chartTarget, areaOptions)
    this.chart.render()

    const relativePath = this.urlTwoValue
    const monthYearOne = this.monthInputTarget.value + "-01"
    const url = new URL(relativePath, window.location.origin)
    url.searchParams.set("month_year_one", monthYearOne)

    fetch(url)
      .then(r => r.json())
      .then(data => {
        const categoryAggregates = this.aggregateDataByCategories(data)

        const negativeAmountsLabels = Object.keys(categoryAggregates.outcomeAmounts)
        const negativeAmountsColors = negativeAmountsLabels.map(label => categoryAggregates.categoryColors[label])
        const positiveAmountsLabels = Object.keys(categoryAggregates.incomeAmounts)
        const positiveAmountsColors = positiveAmountsLabels.map(label => categoryAggregates.categoryColors[label])

        const negativeTransactionsLabels = Object.keys(categoryAggregates.outcomeTransactions)
        const negativeTransactionsColors  = negativeTransactionsLabels.map(label => categoryAggregates.categoryColors[label])
        const positiveTransactionsLabels = Object.keys(categoryAggregates.incomeTransactions)
        const positiveTransactionsColors  = positiveTransactionsLabels.map(label => categoryAggregates.categoryColors[label])

        this.renderPieChart(
          this.negativePieChartTarget,
          Object.values(categoryAggregates.outcomeAmounts),
          negativeAmountsLabels,
          this.negativePieChartTarget.dataset.title,
          negativeAmountsColors
        )

        this.renderPieChart(
          this.positivePieChartTarget,
          Object.values(categoryAggregates.incomeAmounts),
          positiveAmountsLabels,
          this.positivePieChartTarget.dataset.title,
          positiveAmountsColors
        )

        this.renderPieChart(
          this.negativeTransactionsPieChartTarget,
          Object.values(categoryAggregates.outcomeTransactions),
          negativeTransactionsLabels,
          this.negativeTransactionsPieChartTarget.dataset.title,
          negativeTransactionsColors
        )

        this.renderPieChart(
          this.positiveTransactionsPieChartTarget,
          Object.values(categoryAggregates.incomeTransactions),
          positiveTransactionsLabels,
          this.positiveTransactionsPieChartTarget.dataset.title,
          positiveTransactionsColors
        )
      })
      .catch(error => {
        console.error("Error fetching pie chart data:", error)
      })
  }

  aggregateDataByCategories(data) {
    const incomeAmounts       = {}
    const outcomeAmounts      = {}
    const incomeTransactions  = {}
    const outcomeTransactions = {}
    const categoryColors      = {}

    data.forEach(d => {
      const categories = Array.isArray(d.category_name) ? d.category_name : [d.category_name]
      const color = d.color

      categories.forEach(category => {
        let price = d.price

        let amounts      = incomeAmounts
        let transactions = incomeTransactions

        if (price < 0) {
          price = price * -1
          amounts      = outcomeAmounts
          transactions = outcomeTransactions
        }

        // if (amounts[category] === undefined) {
        //   amounts[category] = price
        // } else {
        //   amounts[category] += price
        // }
        //
        amounts[category]        = (amounts[category] || 0)      + price
        transactions[category]   = (transactions[category] || 0) + 1
        categoryColors[category] = color
      })
    })

    return { incomeAmounts, outcomeAmounts, incomeTransactions, outcomeTransactions, categoryColors }
  }

  renderPieChart(target, series, labels, title, colors) {
    if (target.chart) {
      target.chart.destroy()
    }

    const options = {
      chart: {
        type: "pie",
        height: target.offsetHeight,
      },
      title: {
        text: title,
        align: "left"
      },
      series: series,
      labels: labels,
      colors: colors,
      legend: {
        show: !this.isTouch
      },
      tooltip: {
        y: {
          formatter: (val) => {
            if (target === this.negativeTransactionsPieChartTarget || target === this.positiveTransactionsPieChartTarget) { return val }

            return `R$ ${val.toLocaleString("pt-BR", { minimumFractionDigits: 2 })}`
          }
        }
      }
    }

    target.chart = new ApexCharts(target, options)
    target.chart.render()
  }
}
