export function paidPricesMatch(installmentPrices, exchangePrices) {
  if (installmentPrices.length !== exchangePrices.length) { return false }

  return normalizedPrices(installmentPrices).every((price, index) => price === normalizedPrices(exchangePrices)[index])
}

export function mirroredPrice(price, sign) {
  return Math.abs(Number(price)) * (sign < 0 ? -1 : 1)
}

function normalizedPrices(prices) {
  return prices.map((price) => Math.abs(Number(price))).sort((left, right) => left - right)
}
