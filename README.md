# 30/Fev

![30/Fev Logo](app/assets/images/logo.png)

## INTRODUCTION

`30/Fev` is a personal finance application built to make financial tracking feel less
like bookkeeping and more like a daily tool that is actually pleasant to use.

The project started as a way to understand spending, installments, exchanges, card
payments, budgets, and investments in a single place, and gradually evolved into a
broader product: a finance app with strong domain rules, mobile/PWA support, and a
UI focused on practical day-to-day navigation.

## What The App Does

`30/Fev` brings together several parts of personal finance in one system:

- cash transactions and cash installments
- card transactions and card installments
- budgets with category and entity filters
- investments and bank accounts
- exchange-return flows between transactions and entities
- references for card billing cycles
- chat, notifications, and PWA-friendly navigation

The goal is not only to register money movement, but also to preserve the logic around
how that movement actually happens.

## Project Direction

Sprint 0 (`Iruka`) was the pre-coding planning phase: shaping the product idea,
writing model structures, and deciding the first domain relationships before real
implementation started.

Sprint 1 (`Gaara`) focused on building the product core: the main financial models,
transaction relationships, installments, exchanges, CRUD flows, and the first usable
interface.

Sprint 2 (`Sasuke`) focused on product hardening: better mobile and PWA experience,
Hotwire-driven flows, bulk actions, references, chat, notifications, infrastructure
improvements, naming consistency, and performance cleanup.

Sprint 3 (`Jiraya`) is the next more deliberately planned sprint, focused on
recurrence, scenario planning, analysis screens, stronger consistency rules, and
faster day-to-day workflows.

For the detailed sprint history:

- [Sprint 0](./SPRINT_0.md)
- [Sprint 1](./SPRINT_1.md)
- [Sprint 2](./SPRINT_2.md)
- [Sprint 3](./SPRINT_3.md)

## Stack

Main technologies used in the project:

- Ruby on Rails
- Hotwire / Turbo / Stimulus
- PostgreSQL
- Phlex and custom UI components
- Tailwind CSS
- PWA support
- Solid Cable

## Current Focus

The project is currently at the stage where the business logic already exists in good
depth, and the main effort is refining usability, consistency, performance, and
long-term maintainability.

That means improving navigation, reducing friction in common flows, tightening
financial rules, and continuing to make the app feel closer to a real product than a
prototype.
