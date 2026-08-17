import assert from "node:assert/strict"
import test from "node:test"

import { isForwardAdjacentMonth } from "../../app/javascript/lib/reference_merge_mode.mjs"

test("accepts only the calendar month immediately after the source", () => {
  assert.equal(isForwardAdjacentMonth("2026-08", "2026-09"), true)
  assert.equal(isForwardAdjacentMonth("2026-12", "2027-01"), true)
  assert.equal(isForwardAdjacentMonth("2026-09", "2026-08"), false)
  assert.equal(isForwardAdjacentMonth("2026-08", "2026-10"), false)
})

test("rejects blank, malformed, and out-of-range month values", () => {
  assert.equal(isForwardAdjacentMonth("", "2026-09"), false)
  assert.equal(isForwardAdjacentMonth("2026-8", "2026-09"), false)
  assert.equal(isForwardAdjacentMonth("2026-13", "2027-01"), false)
})
