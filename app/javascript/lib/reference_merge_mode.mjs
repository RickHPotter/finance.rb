export function isForwardAdjacentMonth(source, target) {
  const sourceParts = parseMonth(source)
  const targetParts = parseMonth(target)

  if (!sourceParts || !targetParts) return false

  const nextMonth = sourceParts.month === 12
    ? { year: sourceParts.year + 1, month: 1 }
    : { year: sourceParts.year, month: sourceParts.month + 1 }

  return nextMonth.year === targetParts.year && nextMonth.month === targetParts.month
}

function parseMonth(value) {
  const match = /^(\d{4})-(\d{2})$/.exec(value || "")
  if (!match) return null

  const year = Number.parseInt(match[1], 10)
  const month = Number.parseInt(match[2], 10)

  if (month < 1 || month > 12) return null

  return { year, month }
}
