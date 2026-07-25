import { automaticForeground, normalizeHex } from "./category_colour_contrast.mjs"

export const NEUTRAL_CHART_PRESENTATION = Object.freeze({
  background: "#e2e8f0",
  foreground: "#0f172a"
})

export function resolveCategoryChartPresentation(entry = {}, fallbackBackground = null) {
  const background = normalizeHex(entry.background || entry.colour || entry.color || fallbackBackground)
  if (!background) return NEUTRAL_CHART_PRESENTATION

  const foreground = normalizeHex(entry.foreground) || automaticForeground(background)
  if (!foreground) return NEUTRAL_CHART_PRESENTATION

  return Object.freeze({ background, foreground })
}
