# KAKASHI-15 Turbo Navigation: Decisions and Test Matrix

## Resolved Product Decisions

### D1. Is `center_container` the application router?

Decision: no. It may remain a layout wrapper, but top-level resources navigate with
Turbo Drive at `_top`.

### D2. Should top-level links request Turbo Stream format?

Decision: no. They request canonical HTML URLs. Streams are reserved for local
updates.

### D3. What status follows successful create/update/destroy?

Decision: `303 See Other` to an explicit canonical GET destination for both Turbo and
non-Turbo submissions.

### D4. What happens to the successful form in browser history?

Decision: its entry is replaced by the redirect destination so Back does not reopen a
stale submitted form.

### D5. What happens on validation failure?

Decision: render with `422`, retain values and stacked notifications, and keep the
new/edit URL visible.

### D6. Where does create success go?

Decision: the validated return/index destination, except an explicit chained entry
continues at its canonical next-form URL.

### D7. Where does update success go?

Decision: a validated explicit return destination when supplied, otherwise the
resource family's documented index or show destination. The choice is visible in the
controller/action contract.

### D8. Where does destroy success go?

Decision: a validated return destination or canonical index. It never leaves the
destroyed member URL visible.

### D9. How are filters/months/context retained?

Decision: explicit allowlisted navigation state, not a stale URL or arbitrary copied
params.

### D10. Is `return_to` trusted?

Decision: no. It must be relative, same-application, route-allowlisted, and
query-key-allowlisted, with a canonical fallback.

### D11. What happens to chained create/duplicate?

Decision: preserve it. Successful intermediate forms are replaced in history, the next
screen has refreshable permitted state, and finishing returns to the intended index.

### D12. Is duplicate a top-level screen?

Decision: yes. Its member duplicate URL canonically identifies the source used to
build the form.

### D13. Do bulk and modal actions become redirects?

Decision: only if they move to another top-level screen. Genuine same-index bulk
updates, modals, overlays, lazy fragments, and inline state changes remain streams.

### D14. Do Turbo and non-Turbo requests diverge?

Decision: not in destination or status semantics. Only the rendering mechanism for a
bounded failure/local update may differ.

### D15. Are current conversations deferred entirely to KAKASHI-13?

Decision: no. KAKASHI-15 fixes their current URL/history regressions without adding
friendship architecture. KAKASHI-13 later builds on the contract.

### D16. Are internal ledgers deferred entirely to KAKASHI-19?

Decision: no. Current route parameters and browser history are corrected without
expanding public-sharing or authorization scope.

## Core Request Matrix

| Scenario | Expected result |
| --- | --- |
| GET top-level index/new/show/edit | HTML response at canonical URL |
| top-level link inside frame | targets `_top` |
| top-level generated path | no `.turbo_stream` format |
| successful Turbo create | `303` canonical GET location |
| successful non-Turbo create | same `303` location |
| successful update | `303` explicit return/index/show location |
| successful destroy | `303` return/index location |
| failed create | `422`, entered new form values |
| failed update | `422`, entered edit form values |
| failed destroy | controlled `422`/redirect per resource, no false success |
| nested frame request | bounded matching frame/stream, not full application document |
| direct deep link | correct full screen and URL |
| refresh | same resource and state |

## Navigation-State Security Matrix

| Scenario | Expected result |
| --- | --- |
| allowlisted relative index path | accepted |
| absolute URL | rejected |
| protocol-relative URL | rejected |
| another host | rejected |
| malformed URI | rejected |
| non-GET mutation path | rejected |
| route outside resource allowlist | rejected |
| unknown query key | stripped/rejected |
| oversized array/state | bounded |
| foreign user card/account ID | rejected or not found |
| foreign context/scenario | rejected or not found |
| valid filter/month/sort keys | retained |
| no return state | canonical resource fallback |

## Browser History Matrix

| Journey | Expected result |
| --- | --- |
| index -> new | URL becomes `/resource/new` |
| new -> failed save | URL remains `/resource/new` |
| new -> successful save -> index | URL becomes index |
| Back after successful create | pre-new index, not submitted form |
| Forward | canonical destination, no resubmit |
| show -> edit | URL becomes member `/edit` |
| edit -> failed save | URL remains member `/edit` |
| edit -> successful save | canonical destination |
| Back after successful update | screen before edit |
| show -> destroy -> index | destroyed member URL removed from active history flow |
| Back after destroy | no actionable stale destroyed screen |
| index filters -> show -> Back | filtered index restored |
| direct show -> related dashboard | each URL matches screen |
| browser refresh anywhere | server renders same screen |

## Cash/Card Chain Matrix

| Scenario | Expected result |
| --- | --- |
| create one and finish | canonical filtered index |
| create and continue | canonical next new-form URL |
| refresh continued form | chain state restored safely |
| finish without saving blank form | canonical index |
| duplicate one | duplicate source URL renders seeded form |
| duplicate and continue | next owned source/state retained |
| invalid chain record ID | rejected/fallback, no foreign record |
| Back after completed chain | screen before chain, not intermediate successful forms |
| selected card/year/month | retained at final card index |
| cross cash/card link | destination URL and screen agree |

## In-Place Stream Matrix

| Scenario | Expected result |
| --- | --- |
| validation notifications | stacked without top-level redirect |
| lazy month change | expected month frame only |
| modal open/submit | modal/result targets only |
| bulk action on same index | index URL/state retained |
| inline paid-state update | member/index URL retained |
| pay in advance | selected card/index URL retained |
| realtime message arrives | conversation URL unchanged |
| Health Check run completes | dashboard/check URL unchanged |
| stream requests top-level view accidentally | regression failure |
| stream inserts `<html>`/full layout in frame | regression failure |

## Resource Matrix

| Resource family | Required browser coverage |
| --- | --- |
| cash transactions | full CRUD, duplicate, chain, cancel, filter restore |
| card transactions | full CRUD, duplicate, chain, card/month restore, pay advance |
| budgets | CRUD, duplicate, bulk, month/filter restore |
| investments | CRUD, chain, account/filter restore |
| subscriptions | CRUD and transaction attachment |
| categories/entities | CRUD, guarded destroy, seeded transaction branch |
| bank accounts/user cards | CRUD, guarded destroy, seeded transaction branch |
| contexts/references/balances | switch, edit/merge, lazy state |
| Health Check/audits | cross-navigation, pagination, repair/run local updates |
| conversations/messages | selection, actionable links, realtime |
| internal ledgers | scoped route/filter/month preservation |

## Manual Verification Matrix

| Scenario | Expected result |
| --- | --- |
| desktop Turbo enabled | address bar always names visible screen |
| mobile/PWA Turbo enabled | same history behavior |
| JavaScript/Turbo unavailable | canonical links/forms remain usable |
| browser Back/Forward repeatedly | no cycles caused by stale frame content |
| refresh after create/update | no form resubmission warning |
| refresh after failure | GET URL reconstructs form; submitted invalid values need not survive hard refresh |
| open link in new tab | full canonical screen |
| copy/paste current URL | same resource/state for authorized user |
| slow lazy frame | top-level URL remains correct |
| English/Portuguese | errors and navigation labels complete |

## Remaining Product Decisions

There are no blocking V1 product decisions. During each resource slice, the exact
successful update destination (show versus index) must preserve that resource's
current user workflow and be recorded in its request examples. A cross-resource
destination that changes product behavior requires explicit review rather than being
hidden in the navigation helper.
