export function _applyMask(value) {
  const isNegative = value.startsWith("-")
  value = value.replace(/[^\d]/g, "")
  value = (value / 100).toFixed(2).toString()
  value = value.replace(/\B(?=(\d{3})+(?!\d))/g, ".")
  return (isNegative ? "-R$ " : "R$ ") + value

}

export function _removeMask(value) {
  return value.replace(/[^\d-]/g, "")
}
