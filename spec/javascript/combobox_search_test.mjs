import assert from "node:assert/strict"
import test from "node:test"

import {
  comboboxMatchTier,
  comboboxSearchRank,
  nextComboboxSelectionIndex,
  normalizeComboboxText,
  rankVisibleComboboxItems,
  sortComboboxMatches
} from "../../app/javascript/lib/combobox_search.mjs"

test("normalizes accents, case, and repeated whitespace while preserving punctuation", () => {
  assert.equal(normalizeComboboxText("  SÃO   Paulo-01  "), "sao paulo-01")
})

test("classifies exact, starts-with, word-start, and substring primary matches", () => {
  assert.equal(comboboxMatchTier("sale", "sale"), 1)
  assert.equal(comboboxMatchTier("sales tax", "sale"), 2)
  assert.equal(comboboxMatchTier("summer sale", "sale"), 3)
  assert.equal(comboboxMatchTier("resale", "sale"), 4)
})

test("classifies aliases internally while keeping every alias below primary labels", () => {
  assert.equal(comboboxSearchRank("Main account", "Núbank | 0042", "nubank"), 5)
  assert.equal(comboboxSearchRank("Main account", "Núbank Platinum", "nubank"), 6)
  assert.equal(comboboxSearchRank("Main account", "Núbank Platinum | 0042", "platinum"), 7)
  assert.equal(comboboxSearchRank("Main account", "Supernubank", "nubank"), 8)
  assert.equal(comboboxSearchRank("Nubank reserve", "other", "nubank"), 2)

  const ordered = sortComboboxMatches([
    { id: "alias-exact", rank: 5, originalIndex: 0 },
    { id: "primary-substring", rank: 4, originalIndex: 2 },
    { id: "primary-exact-later", rank: 1, originalIndex: 3 },
    { id: "primary-exact-earlier", rank: 1, originalIndex: 1 }
  ])

  assert.deepEqual(ordered.map(item => item.id), [
    "primary-exact-earlier",
    "primary-exact-later",
    "primary-substring",
    "alias-exact"
  ])
})

test("returns no match for unrelated labels and aliases", () => {
  assert.equal(comboboxSearchRank("Food", "Groceries", "rent"), Number.POSITIVE_INFINITY)
})

test("omits permanent exclusions and returns an empty result set when nothing matches", () => {
  const items = [
    { id: "hidden", label: "Rent", permanentlyHidden: true, originalIndex: 0 },
    { id: "visible", label: "Food", permanentlyHidden: false, originalIndex: 1 },
    { id: "later", label: "Utilities", permanentlyHidden: false, originalIndex: 2 }
  ]

  assert.deepEqual(rankVisibleComboboxItems(items, "rent"), [])
  assert.deepEqual(rankVisibleComboboxItems(items, "food").map(item => item.id), ["visible"])
  assert.deepEqual(rankVisibleComboboxItems([...items].reverse(), "").map(item => item.id), ["visible", "later"])
})

test("keyboard traversal wraps through the reordered visible result count", () => {
  const orderedVisibleIds = rankVisibleComboboxItems([
    { id: "third", label: "Summer sale", originalIndex: 0 },
    { id: "first", label: "Sale", originalIndex: 2 },
    { id: "second", label: "Sales tax", originalIndex: 1 },
    { id: "excluded", label: "Sale", permanentlyHidden: true, originalIndex: 3 }
  ], "sale").map(item => item.id)

  let selectedIndex = nextComboboxSelectionIndex(null, orderedVisibleIds.length, 1)
  assert.equal(orderedVisibleIds[selectedIndex], "first")
  selectedIndex = nextComboboxSelectionIndex(selectedIndex, orderedVisibleIds.length, 1)
  assert.equal(orderedVisibleIds[selectedIndex], "second")
  selectedIndex = nextComboboxSelectionIndex(selectedIndex, orderedVisibleIds.length, -1)
  assert.equal(orderedVisibleIds[selectedIndex], "first")
  selectedIndex = nextComboboxSelectionIndex(selectedIndex, orderedVisibleIds.length, -1)
  assert.equal(orderedVisibleIds[selectedIndex], "third")
  assert.equal(nextComboboxSelectionIndex(null, 0, 1), null)
})
