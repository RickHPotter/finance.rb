# SUMMARY

<!--toc:start-->
- [SUMMARY](#summary)
  - [INTRODUCTION](#introduction)
  - [SPRINT PLANNING 0: IRUKA](#sprint-planning-0-iruka)
    - [IRUKA-01/app-00: Define the product idea and scope](#iruka-01app-00-define-the-product-idea-and-scope)
    - [IRUKA-02/be-00: Write the first domain model structures](#iruka-02be-00-write-the-first-domain-model-structures)
    - [IRUKA-03/app-01: Bootstrap the project](#iruka-03app-01-bootstrap-the-project)
<!--toc:end-->

## INTRODUCTION

The creation of __30/Fev__ came from the need to evaluate financial habits not as a
hobby, but as a necessity. Before the app became code, it first had to become a
clearer idea: what should be tracked, how financial relationships should behave, and
what kind of tool this should become in daily life.

## SPRINT PLANNING 0: IRUKA

__IRUKA__ is the pre-coding sprint. This was the planning phase: understanding the
problem, writing down model structures, deciding the first relationships, and shaping
the product before implementation started.

There was effectively no real code here beyond generating the Rails application. The
work was much more about reducing confusion early so Sprint 1 could begin with a
clearer domain in mind.

I remember writing down all the SQL structure I wanted to use, and how installments were going to be.
The planning took quite some time but I believe that helped a lot. It felt natural to move to Sprint 1
after this.

### IRUKA-01/app-00: Define the product idea and scope

- Subtasks:
  - ✅ Decide that the project should focus on personal finance as a daily-use tool,
    not just a bookkeeping exercise.
  - ✅ Define the first use cases around transactions, installments, cards,
    entities, budgets, and investments.

### IRUKA-02/be-00: Write the first domain model structures

- Subtasks:
  - ✅ Write the initial model structures before implementation.
  - ✅ Think through the first relationships between transactions, installments,
    cards, entities, and other finance concepts.
  - ✅ Use this phase to reduce ambiguity before touching application code.

### IRUKA-03/app-01: Bootstrap the project

- Subtasks:
  - ✅ Establish and write the starting point for Sprint 1.
  - ✅ Run `rails new`.
