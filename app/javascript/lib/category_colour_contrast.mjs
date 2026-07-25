export const MINIMUM_RATIO = 4.5
export const BLACK = "#000000"
export const WHITE = "#ffffff"

const HEX_PATTERN = /^#?([0-9a-f]{3}|[0-9a-f]{6})$/i

export function normalizeHex(value) {
  if (typeof value !== "string") return null

  const match = value.trim().match(HEX_PATTERN)
  if (!match) return null

  let digits = match[1].toLowerCase()
  if (digits.length === 3) digits = [...digits].map(character => character.repeat(2)).join("")
  return `#${digits}`
}

export function relativeLuminance(value) {
  const normalized = normalizeHex(value)
  if (!normalized) return null

  const channels = normalized
    .slice(1)
    .match(/.{2}/g)
    .map(channel => Number.parseInt(channel, 16) / 255)
    .map(linearize)

  return (0.2126 * channels[0]) + (0.7152 * channels[1]) + (0.0722 * channels[2])
}

export function contrastRatio(first, second) {
  const firstLuminance = relativeLuminance(first)
  const secondLuminance = relativeLuminance(second)
  if (firstLuminance === null || secondLuminance === null) return null

  const lighter = Math.max(firstLuminance, secondLuminance)
  const darker = Math.min(firstLuminance, secondLuminance)
  return (lighter + 0.05) / (darker + 0.05)
}

export function automaticForeground(background) {
  const blackRatio = contrastRatio(background, BLACK)
  const whiteRatio = contrastRatio(background, WHITE)
  if (blackRatio === null || whiteRatio === null) return null

  return blackRatio >= whiteRatio ? BLACK : WHITE
}

export function assessContrast(background, foreground, minimumRatio = MINIMUM_RATIO) {
  const normalizedBackground = normalizeHex(background)
  const normalizedForeground = normalizeHex(foreground)
  if (!normalizedBackground || !normalizedForeground) return null

  const ratio = contrastRatio(normalizedBackground, normalizedForeground)
  return Object.freeze({
    background: normalizedBackground,
    foreground: normalizedForeground,
    ratio,
    minimumRatio,
    passing: ratio >= minimumRatio,
    suggestedForeground: automaticForeground(normalizedBackground)
  })
}

export function formatRatio(ratio) {
  return Number.isFinite(ratio) ? `${ratio.toFixed(2)}:1` : "—"
}

function linearize(channel) {
  return channel <= 0.04045
    ? channel / 12.92
    : Math.pow((channel + 0.055) / 1.055, 2.4)
}
