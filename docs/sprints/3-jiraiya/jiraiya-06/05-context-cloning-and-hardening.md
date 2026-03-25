# JIRAIYA-06 Slice 4-5: Cloning And Context UX

## Goal

Turn `Context` from a scoped runtime concept into a usable scenario feature:

- clone one context into another safely
- let the user navigate and switch scenarios explicitly
- prevent stale UI flows from writing into the wrong context after a switch

## Delivered

### Cloning

- `Logic::ContextCloneService`
- clone lineage through `source_context_id`
- explicit `scenario_key` support for shared derived scenarios
- context-scoped `Reference` uniqueness so cloned card cycles remain valid
- rollback coverage so partial clones do not survive failures

### Context UX

- session-backed footer context switcher
- tree-style `contexts#index`
- `contexts#show`
- `contexts#new`
- derived-context creation from any node in the tree
- scenario badges on key scenario-sensitive screens

### Switching Safety

- redirect away from invalid `conversations#show` URLs after context switch
- stale cash-transaction forms now carry their origin `context_id`
- create/update is rejected if the submitted form context no longer matches the
  active session context

## Result

At the end of these slices:

- a user can create derived contexts from existing ones
- financial data is cloned into an isolated scenario timeline
- the app exposes a visible context tree and active-context state
- switching contexts no longer allows a stale transaction form to save into the
  wrong scenario

## Boundary

This slice still does not define final archive/destroy semantics for contexts.
Derived-context removal remains a product decision because scenarios can be shared
across users through `scenario_key`.
