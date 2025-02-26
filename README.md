# SUMMARY

<!--toc:start-->
- [SUMMARY](#summary)
  - [INTRODUCTION](#introduction)
  - [SPRINT PLANNING I: GAARA](#sprint-planning-i-gaara)
    - [GAARA-01/be-01: Finish late Model Specs](#gaara-01be-01-finish-late-model-specs)
    - [GAARA-02/be-02: Create models that revolve around MoneyTransaction](#gaara-02be-02-create-models-that-revolve-around-moneytransaction)
    - [GAARA-03/be-03: Implement 'buy now, pay later' system](#gaara-03be-03-implement-buy-now-pay-later-system)
    - [GAARA-04/app-01: Update stack and add Docker](#gaara-04app-01-update-stack-and-add-docker)
    - [GAARA-05/be-04: Create EntityTransaction Model; Installments in MoneyTransaction](#gaara-05be-04-create-entitytransaction-model-installments-in-moneytransaction)
    - [GAARA-06/be-05: Create Exchange Model](#gaara-06be-05-create-exchange-model)
    - [GAARA-07/be-06: Refine Exchange Model](#gaara-07be-06-refine-exchange-model)
    - [GAARA-08/be-07: Refine Seeds and fix possible bugs found at this stage](#gaara-08be-07-refine-seeds-and-fix-possible-bugs-found-at-this-stage)
    - [GAARA-09/fe-01: Refine AutocompleteSelect](#gaara-09fe-01-refine-autocompleteselect)
    - [GAARA-10/fe-02: Create a Component that allows to select multiple options](#gaara-10fe-02-create-a-component-that-allows-to-select-multiple-options)
    - [GAARA-11/fe-03: Refine `TabComponent`, Create CRUD for Category, Entity and Card](#gaara-11fe-03-refine-tabcomponent-create-crud-for-category-entity-and-card)
    - [GAARA-12/fe-04: Finish the MVP](#gaara-12fe-04-finish-the-mvp)
<!--toc:end-->

## INTRODUCTION

The creation of this app came from the need to evaluate financial habits not as
a hobby, but as a necessity. I plan on making an easy-to-use app that will swift
into your life and help you take care of what comes harder in life: stability and
peace.

## SPRINT PLANNING I: GAARA

Starting point for a `v0.1` release of my app called `finance.rb` (yeah, `finance.rb`).

This milestone includes covering much of the product logic and providing enough visual resources to use the logic so far applied. As it's the first sprint, it also means we have a lot of TODOs and FIXMEs to recognise during development for next sprints.

__Gaara__ is the first sprint and it is supposed to take longer than the average sprint. The reasons are:

1. I'm starting just now, this is, after all, the first sprint. Like most projects at their kick-start, it is just one person: me.

2. I had a 2-week holiday and didn't touch the project whatsoever.

3. I had a week off due to a -failed- participation in a take home challenge for a job interview, and I didn't touch the project.

4. I had then a two-week span that I was participating in an internal recruitment at my job. I kept on working on this project, but way less.

5. I started working full-time as a dev where I was an intern after getting the rightful promotion. This caused me to several times overwork (willingly).

6. After studying non-stop for about a whole year, I spontaneously decided to take April as my luxury month to rest. I watched The Office US (I had only watched the UK version before).

7. I had a quick come-back in the second half of April.

8. I found myself finishing two issues/PR back in May through the first third June, and took a break from the project until the last third of July, when I had a quick come-back.

9. In the span of August I took my little free time to finish a pending issue.

10. Decided to focus more on my work and my final college months before graduation and only came back in December.

11. Came back in `December the 19th` to start the penultimate issue filling it up with many other features that were not asked in the task. PS: There was a problem with the `fe-03` PR, I had to rewrite Author and that caused the date of commits to all default to `January the 25th`, but they were spanning from `December the 19th`.

Possible Downtime: 6 months and a half

### GAARA-01/be-01: Finish late Model Specs

- Subtasks:
  - ✅ Create Models Specs for `CardTransaction` and `Installment`.

### GAARA-02/be-02: Create models that revolve around MoneyTransaction

- Subtasks:
  - ✅ Use TDD approach; create the tests before.
  - ✅ Create the Models `Bank`, `UserBankAccount` and `Investment`.
  - ✅ `UserBankAccount` should belong_to a user and a bank.
  - ✅ `MoneyTransaction` and `Investment` should belong_to a user_bank_account.
- Extra:
  - ✅ Created concerns for `MonthYear` and Callbacks for `StartingPrice` and `Active`.

### GAARA-03/be-03: Implement 'buy now, pay later' system

- Subtasks:
  - ✅ Use TDD approach; create the tests before.
  - ✅ Implement idea behind how transactions are built based on other models:
    - 1 ✅ Create callbacks for investments to handle the money_transaction.
    - 2 ✅ Create callbacks for card_transactions to handle the money_transaction.
- Extra:
  - ✅ Added `DatabaseCleanerActiveRecord` gem to avoid some issues with specs.
  - ✅ Created a `FakerHelper` in spec/support to clear `UniqueGenerator` between examples.
  - ✅ Created a `FactoryHelper` in an initialiser and added a custom_create method.
  - ✅ Changed Transaction Model into `MoneyTransaction` because of reserved keyword.
  - ✅ Merged migrations and fixed breaking changes concerning naming conventions.
  - ✅ Added closing_date and days_between_closing_and_due fields to `UserCard`.
  - ✅ Adjusted set_month_year to comply with current_closing/due_date of `UserCard`.
  - ✅ Refined `Installment` Spec based on how the `Investment` spec was created.
  - ✅ Standardised the specs blocks and documentation.

### GAARA-04/app-01: Update stack and add Docker

- Subtasks:
  - ✅ Successfully update __Ruby on Rails__ from 7.0.8 to 7.1.2.
  - ✅ Successfully update __Ruby__ from 3.2.2 to 3.3.0.
  - ✅ Add Docker to the project with Docker Compose for development.
- Extra:
  - ✅ Added `neovim` to generated Docker.
  - ✅ Made it possible to run app in production mode in and outside of Docker.
  - ✅ Added and configured `Bullet` gem for development.

### GAARA-05/be-04: Create EntityTransaction Model; Installments in MoneyTransaction

- Issues:
  - [#6](https://github.com/RickHPotter/finance.rb/issues/6)

- Subtasks:
  - ✅ Use TDD approach; create the tests before.
  - ✅ Create Model that links a `([card/money]_)transaction` to a (number of) `entit(ies)`.
  - ✅ The table should include the fields: [id, timestamps, is_payer as boolean,
       price as decimal, status (pending, finished)].
  - ✅ Remove entity_id from `(Card/Money)Transaction`.
  - ✅ When an entity_transaction is not a payer:
    - 1 ✅ The entity_transaction should have `is_payer: false, status = 'finished'`,
           amount_to_be_returned and amount_returned should be 0.00.
- Extra:
  - ✅ APP: Enabled `YJIT` with an initialiser.
  - ✅ APP: Added `Confirmable` in Devise.
  - ✅ APP: Added `SimpleCov` for tracking test coverage.
  - ✅ APP: Added `GuardRspec` for safer development.

### GAARA-06/be-05: Create Exchange Model

- Issues:
  - [#8](https://github.com/RickHPotter/finance.rb/issues/8)
  - [#14](https://github.com/RickHPotter/finance.rb/issues/14)
  - [#15](https://github.com/RickHPotter/finance.rb/issues/15)

- Subtasks:
  - ✅ Use TDD approach; create the tests before.
  - ✅ Create Model that will reference an entity_transaction and generate a money_transaction.
  - ✅ The table should include the fields: [id, timestamps,
       exchange_type (monetary, non-monetary), amount_to_be_returned, amount_returned].
  - ✅ `CardTransaction` should `has_many :entity_transactions`,
       `EntityTransaction` should `has_many :exchanges`,
       `Exchange` should `belongs_to :money_transaction, optional: true`.
  - ✅ One entity_transaction should be created for every entity card_transaction.
  - ✅ One exchange should be created for every paying entity_transaction.
- Extra:
  - ✅ Made a join table for `Transaction` and `Category` (like `EntityTransaction`).
  - ✅ Made a Concern for `CategoryTransaction` (like `EntityTransactable`).
  - ✅ Made an `Installable` Concern to be used by both `Transactions`.
  - ✅ Made possible to change the amount of installments in a `Transactable`.
  - ✅ Made possible to change the amount of entity_transactions in a `Transactable`.
  - ✅ Made possible to change the amount of exchanges in an `EntityTransaction`.
  - ✅ Added `EntityTransaction` specs for updates in entity_transaction_attributes.
  - ✅ Added `Exchange` specs for updates in exchanges_count and exchange_attributes.
  - ✅ Added `CategoryTransaction` specs for callbacks.

### GAARA-07/be-06: Refine Exchange Model

- Issues:
  - [#8](https://github.com/RickHPotter/finance.rb/issues/8)
  - [#16](https://github.com/RickHPotter/finance.rb/issues/16)

- Subtasks:
  - ✅ Use TDD approach; create the tests before.
  - ✅ One money_transaction should be created for every monetary exchange,
       with a builtin `category = 'Exchange Return'` and no entity_transaction.
  - ✅ Given the flow of [card_transaction -> entity_transaction <-> exchange -> money_transaction]:
    - 1 ✅ if card_transaction has entity_transaction with exchanges, it should have
        `Exchange` category.
    - 2 ✅ if card_transaction has no entity_transaction with exchanges, its category
        `Exchange` is dropped.
    - 3 ✅ if card_transaction wipes entity_transaction, everything dies.
    - 4 ✅ if entity_transaction is not a payer, the exchange should cease to exist.
    - 5 ✅ if exchange is non_monetary, the money_transaction should cease to exist.
- Extra:
  - ✅ Removed amount_returned and amount_to_be_returned from `Exchange` Model.
  - ✅ Added price and starting_price attributes to `Exchange` Model.
  - ✅ Added paid boolean method to `MoneyTransaction` Model.
  - ✅ Added `Exchange` specs for both exchange_types.
  - ✅ Added built_in boolean attribute for `Category`.
  - ✅ Created a helper for Nested Attributes.

### GAARA-08/be-07: Refine Seeds and fix possible bugs found at this stage

- Issues:
  - [#16](https://github.com/RickHPotter/finance.rb/issues/16)

- Subtasks:
  - ✅ Refine seeds to include all models.
  - ✅ Fix possible bugs found at this stage.
  - ✅ Review current specs and refactor if possible.
- Extra:
  - ✅ Switched from `Sprockets` to `Propshaft`.
  - ✅ Added and tidied up `rubocop` and `erb_lint`, and added `CI`.
  - ✅ Created a new request spec that tests the `Exchange` flow.
  - ✅ Refactored the Exchange flow to nested-form using `RailsNestedForm` stimulus.
  - ✅ Made possible to change `FK` of `CardTransaction` (should create/use another money_transaction).
  - ✅ Made possible to change `FK` of `Investment` (should create/use another money_transaction).
  - ✅ Remodelled `Installment` to act like `Exchange`. Join Table that creates 1 parent.
  - ✅ Created a `PORO` for handling `CardTransaction` parameters in request specs.
  - ✅ Removed hard business logic from card_transaction model spec to request spec.
  - ✅ Migrates from much-appreciated `ModelSpecHelper` Custom Validation to `ShouldaMatchers`.
  - ✅ Creates `CI` `binstub` to make it easier to run `CI` locally before pushing.
  - ✅ Reviews and makes necessary changes to docs.

### GAARA-09/fe-01: Refine AutocompleteSelect

- Issues:
  - [#10](https://github.com/RickHPotter/finance.rb/issues/10)

- Subtasks:
  - ✅ Use TDD approach; create the tests before.
  - ✅ Remove `AutocompleteSelect` in favour of `HotwireCombobox` by _Jose Farias_.
    - ✅ When typing, the first option should be rendered in the input, but with font-light.
    - ✅ Add option to use a round-colour or an icon or a picture on the far-left
  - ✅ Fix #money_transaction_date of both `Installment` and `CardTransaction`.
- Extra:
  - ✅ Add `RailsAutosave` stimulus component.
  - ✅ Add `TextareaAutogrow` stimulus component.
  - ✅ Implement a blinking animation (terminal-like) for autosave component.
  - ✅ Import `flowbite-datepicker` (and not use it).
  - ✅ Create `flowbite-datepicker` stimulus controller (and not use it).
  - ✅ Create `HotwireDatepicker` gem repo (and not develop it).
  - ✅ Create reactive-form stimulus controller that handles card_transaction form.
    - ✅ Add several validations client-side.
    - ✅ Add a mask feature to prices.
    - ✅ Add controller action to handle the amount of installments fields.
    - ✅ Add controller actions to update dates and prices of installments.
    - ✅ Add rails model methods to update month and year without creating object.
  - ✅ Create a `RailsDate` JavaScript model that handles date better than JavaScript's.
  - ✅ Improve dramatically form html with more concise formatting.
  - ✅ Use a more fitting concept of installments nested_fields for this project.
  - ✅ Update `TextFieldComponent` to be less more rails-like.
  - ✅ Add fonts.
  - ✅ Improve (or rather fix) form responsiveness when creating a card_transaction.
  - ✅ Successfully update __Ruby__ from 3.3.0 to 3.3.2.
  - ✅ Successfully update __Ruby on Rails__ from 7.1.2 to 7.1.3.3.

### GAARA-10/fe-02: Create a Component that allows to select multiple options

- Issues:
  - [#11](https://github.com/RickHPotter/finance.rb/issues/11)

- Subtasks:
  - ✅ Use TDD approach; create the tests before.
  - ✅ Hack `HotwireCombobox` inside `ReactiveForm` for Continuous Selection.
  - ✅ Create Chips Component that interacts with `HotwireCombobox`.
  - ✅ Grant many options and add turbo-frame to it as these options are relevant.
  - ✅ Deny an option if already chosen in a previous select.
- Extra:
  - ✅ Fixes bugs concerning installments both on the `frontend` and `backend`.
  - ✅ Move price-related float fields to int cent-based.
  - ✅ Successfully update _Ruby_ from 3.3.2 to 3.3.4.
  - ✅ Successfully update __Ruby on Rails__ from 7.1.2 to 7.2.
  - ✅ Clear up current deprecation warnings based on future update to Rails 8.

### GAARA-11/fe-03: Refine `TabComponent`, Create CRUD for Category, Entity and Card

- Issues:
  - [#12](https://github.com/RickHPotter/finance.rb/issues/12)

- Subtasks:
  - ✅ Create `:index` for `CardTransaction` and `CashTransaction`, based on `_installments`.
  - ✅ Make the `Item` `Struct` of the `TabComponent` cleaner using a Controller Concern.
  - ✅ Enable `TabComponent` to start with its `moving_part` at any `item` and `sub_item`.
  - ✅ Pass in dependents `onClickEvent` of updating their parent's links.
  - ✅ Add form and a minimum CRUD for `UserCards`.
  - ✅ Add form and a minimum CRUD for `Entities`.
  - ✅ Add form and a minimum CRUD for `Categories`.
- Extra:
  - ✅ Create an import service.
  - ✅ Rename `MoneyTransaction` to `CashTransaction` and STI usage of `Installemnts`.
  - ✅ Create of `HasAdvancePayments` Concern for Card Payments in advance.
  - ✅ Use `Hotwire` and `Tailwind` for the `:index` actions of `[Card/Cash]Transaction`.
  - ✅ Include fixed set of colours to `categories`. Bare minimum for now.
  - ✅ Fix the dependent relationships, so that a `User` can self-destruct.
  - ✅ Successfully update __Ruby__ from 3.3.4 to 3.4.1.
  - ✅ Successfully update __Ruby on Rails__ from 7.2.2 to 8.0.1.
  - ✅ Successfully update __Tailwind__ from `v3` to `v4`.

### GAARA-12/fe-04: Finish the MVP

- Issues:
  - [#13](https://github.com/RickHPotter/finance.rb/issues/13)

- Subtasks:
  - ⌛ Use TDD approach; create the tests ~before~ after.
  - ⌛ Fix `FIXMEs`, `TODOs`, and such.
  - ⌛ Come to a decision regarding the change of Dark Mode to `Flowbite`.
  - ⌛ Create the connection of `EntityTransaction` to `CardTransaction` form.
  - ⌛ Create the connection of `Exchange` to `EntityTransaction` sub-form.
  - ⌛ Add form for `CashTransaction`.
  - ⌛ Use modern `datatables`, (maybe) with `Hotwire` and `Pagy` for the `:index`.
  - ⌛ Create search sub_link in `CardTransaction`'s `:index`.
  - ⌛ Fix locale from end to end in whole application.
