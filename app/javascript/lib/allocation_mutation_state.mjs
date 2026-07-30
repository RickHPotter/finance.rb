export const ALLOCATION_ACTIONS = Object.freeze([
  "category_add",
  "category_remove",
  "category_switch",
  "entity_add",
  "entity_remove",
  "entity_switch"
])

export function uniqueOwnerIds(values) {
  const normalized = Array.from(values || [])
    .filter((value) => value !== null && value !== undefined)
    .map((value) => String(value).trim())
    .filter(Boolean)

  return [...new Set(normalized)]
}

export function previewReady({ ownerIds, selectedRowCount, operation, sourceId, destinationId }) {
  if (uniqueOwnerIds(ownerIds).length === 0 || Number(selectedRowCount) <= 0) return false
  if (operation === "add") return String(destinationId || "").length > 0
  if (operation === "remove") return String(sourceId || "").length > 0
  if (operation === "switch") return String(sourceId || "").length > 0 && String(destinationId || "").length > 0

  return false
}
