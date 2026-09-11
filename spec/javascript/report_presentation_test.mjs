import assert from "node:assert/strict"
import test from "node:test"

import {
  fetchReportJson,
  formatCompactReportCurrency,
  formatReportCurrency,
  showReportState
} from "../../app/javascript/lib/report_presentation.mjs"

test("formats report money consistently across English and Brazilian Portuguese", () => {
  assert.equal(formatReportCurrency(3361.12, "en", "BRL"), "R$ 3,361.12")
  assert.equal(formatReportCurrency(-75, "en", "BRL"), "R$ -75.00")
  assert.equal(formatReportCurrency(3361.12, "pt-BR", "BRL"), "R$ 3.361,12")
  assert.equal(formatReportCurrency(-75, "pt-BR", "BRL"), "R$ -75,00")
  assert.equal(formatCompactReportCurrency(12500, "en", "BRL"), "R$ 12.5K")
})

test("switches report states without leaving stale visible panels", () => {
  const element = fakeElement()
  const targets = {
    loading: fakeElement(["hidden"]),
    error: fakeElement(["hidden"]),
    empty: fakeElement(["hidden"]),
    content: fakeElement()
  }

  showReportState(element, targets, "error")

  assert.equal(element.attributes["aria-busy"], "false")
  assert.deepEqual([...targets.loading.classList.values], ["hidden"])
  assert.deepEqual([...targets.error.classList.values], ["flex"])
  assert.deepEqual([...targets.empty.classList.values], ["hidden"])
  assert.deepEqual([...targets.content.classList.values], ["hidden"])
})

test("fetches JSON reports and surfaces the server error", async () => {
  const previousFetch = globalThis.fetch
  globalThis.fetch = async () => ({ ok: false, json: async () => ({ error: "Report unavailable" }) })

  await assert.rejects(fetchReportJson("/report", undefined, "Fallback"), /Report unavailable/)
  globalThis.fetch = previousFetch
})

function fakeElement(classes = []) {
  const values = new Set(classes)

  return {
    attributes: {},
    classList: {
      values,
      toggle(name, force) {
        if (force) values.add(name)
        else values.delete(name)
      }
    },
    setAttribute(name, value) {
      this.attributes[name] = value
    }
  }
}
