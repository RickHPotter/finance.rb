import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import test from "node:test"

import {
  MINIMUM_RATIO,
  assessContrast,
  automaticForeground,
  contrastRatio,
  formatRatio,
  normalizeHex
} from "../../app/javascript/lib/category_colour_contrast.mjs"

const fixturePath = new URL("../fixtures/category_colour_contrast.json", import.meta.url)
const fixtures = JSON.parse(readFileSync(fixturePath, "utf8"))

test("normalizes the same convenient hex input as Ruby", () => {
  fixtures.normalization.forEach(({ input, normalized }) => {
    assert.equal(normalizeHex(input), normalized)
  })
})

test("calculates the same unrounded WCAG ratios as Ruby", () => {
  fixtures.ratios.forEach(({ background, foreground, ratio }) => {
    assert.ok(Math.abs(contrastRatio(background, foreground) - ratio) < 1e-12)
  })
})

test("selects the same automatic foreground as Ruby", () => {
  fixtures.automatic.forEach(({ background, foreground }) => {
    assert.equal(automaticForeground(background), foreground)
  })
})

test("uses the unrounded threshold while formatting display ratios separately", () => {
  const passing = assessContrast("#ffffff", "#767676")
  const failing = assessContrast("#ffffff", "#777777")

  assert.equal(MINIMUM_RATIO, 4.5)
  assert.equal(passing.passing, true)
  assert.equal(failing.passing, false)
  assert.equal(formatRatio(passing.ratio), "4.54:1")
  assert.equal(formatRatio(failing.ratio), "4.48:1")
  assert.equal(failing.suggestedForeground, "#000000")
  assert.ok(Object.isFrozen(passing))
})

test("rejects invalid, named, functional, and transparent input without producing NaN", () => {
  fixtures.invalid.forEach(value => {
    assert.equal(normalizeHex(value), null)
    assert.equal(contrastRatio(value, "#000000"), null)
    assert.equal(automaticForeground(value), null)
    assert.equal(assessContrast(value, "#000000"), null)
  })
})
