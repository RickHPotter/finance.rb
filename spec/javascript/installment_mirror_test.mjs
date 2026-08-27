import assert from "node:assert/strict"
import test from "node:test"

import { mirroredPrice, paidPricesMatch } from "../../app/javascript/lib/installment_mirror.mjs"

test("matches paid installment and exchange prices while ignoring order and signs", () => {
  assert.equal(paidPricesMatch([-31_163, -30_000], [30_000, 31_163]), true)
  assert.equal(paidPricesMatch([-31_163, -30_000], [31_163, 31_163]), false)
  assert.equal(paidPricesMatch([-31_163], [31_163, 31_163]), false)
})

test("mirrors installment prices using the entity return direction", () => {
  assert.equal(mirroredPrice(-30_111, 1), 30_111)
  assert.equal(mirroredPrice(30_111, -1), -30_111)
})
