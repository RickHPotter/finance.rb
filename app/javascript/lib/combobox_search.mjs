const NO_MATCH = Number.POSITIVE_INFINITY

export function normalizeComboboxText(value) {
  return (value || "")
    .normalize("NFKD")
    .replace(/\p{Mn}/gu, "")
    .toLowerCase()
    .replace(/\s+/g, " ")
    .trim()
}

export function comboboxMatchTier(text, query) {
  if (text === query) { return 1 }
  if (text.startsWith(query)) { return 2 }
  if (text.split(/\s+/).some(word => word.startsWith(query))) { return 3 }
  if (text.includes(query)) { return 4 }

  return NO_MATCH
}

export function comboboxSearchRank(label, aliases, query) {
  const normalizedQuery = normalizeComboboxText(query)
  if (!normalizedQuery) { return 0 }

  const primaryTier = comboboxMatchTier(normalizeComboboxText(label), normalizedQuery)
  if (primaryTier < NO_MATCH) { return primaryTier }

  const aliasTier = parseAliases(aliases).reduce((bestTier, alias) => {
    return Math.min(bestTier, comboboxMatchTier(normalizeComboboxText(alias), normalizedQuery))
  }, NO_MATCH)

  return aliasTier < NO_MATCH ? aliasTier + 4 : NO_MATCH
}

export function sortComboboxMatches(items) {
  return [...items].sort((left, right) => left.rank - right.rank || left.originalIndex - right.originalIndex)
}

export function rankVisibleComboboxItems(items, query) {
  const normalizedQuery = normalizeComboboxText(query)

  return sortComboboxMatches(items.filter(item => !item.permanentlyHidden).map(item => ({
    ...item,
    rank: comboboxSearchRank(item.label, item.aliases, normalizedQuery)
  })).filter(item => item.rank < NO_MATCH))
}

export function nextComboboxSelectionIndex(currentIndex, length, movement) {
  if (length === 0) { return null }

  const startingIndex = currentIndex === null ? (movement < 0 ? 0 : -1) : currentIndex
  return ((startingIndex + movement) % length + length) % length
}

function parseAliases(aliases) {
  return (aliases || "").split("|").map(alias => alias.trim()).filter(Boolean)
}
