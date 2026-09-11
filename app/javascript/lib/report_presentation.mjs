export function observeReportVisibility(element, load, rootMargin = "160px") {
  if (!("IntersectionObserver" in window)) {
    load()
    return null
  }

  const observer = new IntersectionObserver((entries) => {
    if (!entries.some((entry) => entry.isIntersecting)) return

    observer.disconnect()
    load()
  }, { rootMargin })
  observer.observe(element)
  return observer
}

export async function fetchReportJson(url, signal, fallbackError) {
  const response = await fetch(url, {
    headers: { Accept: "application/json" },
    signal
  })
  const payload = await response.json()

  if (!response.ok) throw new Error(payload.error || fallbackError)

  return payload
}

export function showReportState(element, targets, state) {
  element.setAttribute("aria-busy", String(state === "loading"))

  ;["loading", "error", "empty"].forEach((name) => {
    const target = targets[name]
    if (!target) return

    const visible = name === state
    target.classList.toggle("hidden", !visible)
    target.classList.toggle("flex", visible)
  })

  targets.content.classList.toggle("hidden", state !== "content")
}

export function formatReportCurrency(value, locale, currency) {
  const number = Number(value) || 0
  const symbol = currencySymbol(locale, currency)
  const amount = new Intl.NumberFormat(locale, { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(Math.abs(number))
  return `${symbol} ${number < 0 ? "-" : ""}${amount}`
}

export function formatCompactReportCurrency(value, locale, currency) {
  const number = Number(value) || 0
  const symbol = currencySymbol(locale, currency)
  const amount = new Intl.NumberFormat(locale, { notation: "compact", maximumFractionDigits: 1 }).format(Math.abs(number))
  return `${symbol} ${number < 0 ? "-" : ""}${amount}`
}

function currencySymbol(locale, currency) {
  return new Intl.NumberFormat(locale, { style: "currency", currency })
    .formatToParts(0)
    .find((part) => part.type === "currency")?.value || currency
}
