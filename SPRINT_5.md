# SUMMARY

## IDEAS

### Query language for advanced filtering

Consider a free-form query language, or first reserve a parser parameter, for advanced
transaction filtering beyond the current explicit controls.

This is intentionally an idea rather than committed Sprint 5 scope. The existing
`sort` + `direction` contract and dedicated filter fields cover the important daily
workflows, while a query grammar would add substantial parsing, validation,
localization, discoverability, and test complexity.
