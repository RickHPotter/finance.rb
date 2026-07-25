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

test("supports legacy color and colour keys during payload migration", () => {
  assert.deepEqual(resolveCategoryChartPresentation({ color: "#000000" }), { background: "#000000", foreground: "#ffffff" })
  assert.deepEqual(resolveCategoryChartPresentation({ colour: "#ffffff" }), { background: "#ffffff", foreground: "#000000" })
})

test("resolves fallback palette foregrounds with the shared contrast contract", () => {
  assert.deepEqual(resolveCategoryChartPresentation({}, "#dc2626"), { background: "#dc2626", foreground: "#ffffff" })
})

test("uses the accessible neutral pair for malformed or missing backgrounds", () => {
  assert.equal(resolveCategoryChartPresentation({ background: "transparent" }), NEUTRAL_CHART_PRESENTATION)
  assert.equal(resolveCategoryChartPresentation(), NEUTRAL_CHART_PRESENTATION)
})
