import test from "node:test"
import assert from "node:assert/strict"

import {
  NEUTRAL_CHART_PRESENTATION,
  resolveCategoryChartPresentation
} from "../../app/javascript/lib/category_chart_presentation.mjs"

test("keeps an authoritative serialized background and foreground pair", () => {
  assert.deepEqual(
    resolveCategoryChartPresentation({ background: "#ffffff", foreground: "#767676" }, "#000000"),
    { background: "#ffffff", foreground: "#767676" }
  )
})

test("does not treat legacy color and colour keys as category payloads", () => {
  assert.equal(resolveCategoryChartPresentation({ color: "#000000" }), NEUTRAL_CHART_PRESENTATION)
  assert.equal(resolveCategoryChartPresentation({ colour: "#ffffff" }), NEUTRAL_CHART_PRESENTATION)
})

test("resolves fallback palette foregrounds with the shared contrast contract", () => {
  assert.deepEqual(resolveCategoryChartPresentation({}, "#dc2626"), { background: "#dc2626", foreground: "#ffffff" })
})

test("uses the accessible neutral pair for malformed or missing backgrounds", () => {
  assert.equal(resolveCategoryChartPresentation({ background: "transparent" }), NEUTRAL_CHART_PRESENTATION)
  assert.equal(resolveCategoryChartPresentation(), NEUTRAL_CHART_PRESENTATION)
})
