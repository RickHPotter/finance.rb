import assert from "node:assert/strict"
import test from "node:test"

import {
  ALLOCATION_ACTIONS,
  previewReady,
  uniqueOwnerIds
} from "../../app/javascript/lib/allocation_mutation_state.mjs"

test("exposes exactly the six category and entity allocation actions", () => {
  assert.deepEqual(ALLOCATION_ACTIONS, [
    "category_add",
    "category_remove",
    "category_switch",
    "entity_add",
    "entity_remove",
    "entity_switch"
  ])
  assert.equal(Object.isFrozen(ALLOCATION_ACTIONS), true)
})

test("deduplicates parent owner IDs while retaining selected-row counts separately", () => {
  assert.deepEqual(uniqueOwnerIds([3889, "3889", 4001, "", null]), ["3889", "4001"])
})

test("requires owners and the fields needed by each operation", () => {
  const base = { ownerIds: ["3889"], selectedRowCount: 2, sourceId: "", destinationId: "" }

  assert.equal(previewReady({ ...base, operation: "add", destinationId: "85" }), true)
  assert.equal(previewReady({ ...base, operation: "add" }), false)
  assert.equal(previewReady({ ...base, operation: "remove", sourceId: "85" }), true)
  assert.equal(previewReady({ ...base, operation: "remove" }), false)
  assert.equal(previewReady({ ...base, operation: "switch", sourceId: "85", destinationId: "91" }), true)
  assert.equal(previewReady({ ...base, operation: "switch", sourceId: "85" }), false)
  assert.equal(previewReady({ ...base, operation: "unknown", sourceId: "85", destinationId: "91" }), false)
})

test("rejects empty selections even when allocation fields are complete", () => {
  assert.equal(
    previewReady({ ownerIds: [], selectedRowCount: 1, operation: "add", sourceId: "", destinationId: "85" }),
    false
  )
  assert.equal(
    previewReady({ ownerIds: ["3889"], selectedRowCount: 0, operation: "add", sourceId: "", destinationId: "85" }),
    false
  )
})
