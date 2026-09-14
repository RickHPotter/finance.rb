import assert from "node:assert/strict"
import test from "node:test"

import { isForwardAdjacentMonth, mergeModeAvailability } from "../../app/javascript/lib/reference_merge_mode.mjs"

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

test("retains a server-rendered invalid choice on connect but clears it after an edit", () => {
  assert.deepEqual(
    mergeModeAvailability("2026-09", "2026-08", { preserveSelection: true }),
    { available: false, clearSelection: false }
  )
  assert.deepEqual(
    mergeModeAvailability("2026-09", "2026-08"),
    { available: false, clearSelection: true }
  )
  assert.deepEqual(
    mergeModeAvailability("2026-12", "2027-01"),
    { available: true, clearSelection: false }
  )
})
