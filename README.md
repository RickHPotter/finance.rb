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
  - [GAARA-07/be-06: Refine EntityTransaction and Exchange Models](#gaara-07be-06-refine-entitytransaction-and-exchange-models)
  - [GAARA-08/be-07: Refine Seeds and fix possible bugs found at this stage](#gaara-08be-07-refine-seeds-and-fix-possible-bugs-found-at-this-stage)
  - [GAARA-09/fe-01: Refine AutocompleteSelect](#gaara-09fe-01-refine-autocompleteselect)
  - [GAARA-10/fe-02: Create MultiCheckBoxComponent](#gaara-10fe-02-create-multicheckboxcomponent)
  - [GAARA-11/fe-03: Refine TabComponent](#gaara-11fe-03-refine-tabcomponent)
  - [GAARA-12/fe-04: Finish the MVP / Finish remaining Request and System Specs](#gaara-12fe-04-finish-the-mvp-finish-remaining-request-and-system-specs)
<!--toc:end-->

# INTRODUCTION

The creation of this app came from the need to evaluate financial habits not as
a hobby, but as a necessity. I plan on making an easy-to-use app that will swift
into your life and help you take care of what comes harder in life: stability and
peace.

# SPRINT PLANNING I: GAARA

Starting point for a v0.1 release of my app called finance.rb (yeah, finance.rb).

This milestone includes covering much of the product logic and providing enough
visual resources to use the logic so far applied. As it's the first sprint, it
also means we have a lot of TODOs and FIXMEs to recognise during development
for next sprints.

Gaara is the first sprint and it is supposed to take longer than the average
sprint. The reasons are:

1. I'm starting just now, this is, after all, the first sprint.
2. Like most projects at their kick-start, it is just one person: me.
3. I had a 2-week holiday and didn't touch the project whatsoever.

## GAARA-01/be-01: Finish late Model Specs

- Subtasks:
  - ✅ Create Models Specs for Card Transaction and Installments.

## GAARA-02/be-02: Create models that revolve around MoneyTransaction

- Subtasks:
  - ✅ Use TDD approach; create the tests before.
  - ✅ Create the Models Bank, UserBankAccount and Investment.
  - ✅ UserBankAccount should belong_to a User and a bank.
  - ✅ MoneyTransaction and Investment should belong_to a UserBankAccount.
- Extra:
  - ✅ Created concerns for MonthYear and Callbacks for StartingPrice and Active.

## GAARA-03/be-03: Implement 'buy now, pay later' system

- Subtasks:
  - ✅ Use TDD approach; create the tests before.
  - ✅ Implement idea behind how transactions are built based on other models:
    - 1 ✅ Create callbacks for investments to handle the money_transaction.
    - 2 ✅ Create callbacks for card_transactions to handle the money_transaction.
- Extra:
  - ✅ Added DatabaseCleanerActiveRecord gem to avoid some issues with specs.
  - ✅ Created a FakerHelper in spec/support to clear UniqueGenerator between examples.
  - ✅ Created a FactoryHelper in an initialiser and added a custom_create method.
  - ✅ Changed Transaction Model into MoneyTransaction because of reserved keyword.
  - ✅ Merged migrations and fixed breaking changes concerning naming conventions.
  - ✅ Added closing_date and days_between_closing_and_due fields to UserCard.
  - ✅ Adjusted set_month_year to comply with current_closing/due_date of UserCard.
  - ✅ Refined Installment Spec based on how the Investment spec was created.
  - ✅ Standardised the specs blocks and documentation.

## GAARA-04/app-01: Update stack and add Docker

- Subtasks:
  - ✅ Successfully update Ruby on Rails from 7.0.8 to 7.1.2.
  - ✅ Successfully update Ruby from 3.2.2 to 3.3.0.
  - ✅ Add Docker to the project with Docker Compose for development.
- Extra:
  - ✅ Added neovim to generated Docker.
  - ✅ Made it possible to run app in production mode in and outside of Docker.
  - ✅ Added and configured Bullet gem for development.

## GAARA-05/be-04: Create EntityTransaction Model; Installments in MoneyTransaction

- Issues:
  - [#6](https://github.com/RickHPotter/finance.rb/issues/6)

- Subtasks:
  - ✅ Use TDD approach; create the tests before.
  - ✅ Create Model that links a ([card/money]_)transaction to a (number of) entit(ies).
  - ✅ The table should include the fields: [id, timestamps, is_payer as boolean,
       price as decimal, status (pending, finished)].
  - ✅ Remove entity_id from (Card/Money)Transaction.
  - ✅ When a entity_transaction is not a payer:
    - 1 ✅ The entity_transaction should have `is_payer: false, status = 'finished'`,
           amount_to_be_returned and amount_returned should be 0.00.
- Extra:
  - ✅ APP: Enabled YJIT by with an initialiser.
  - ✅ APP: Added Confirmable in Devise.
  - ✅ APP: Added SimpleCov for tracking test coverage.
  - ✅ APP: Added Guard-Rspec for safer development.

## GAARA-06/be-05: Create Exchange Model

- Issues:
  - [#8](https://github.com/RickHPotter/finance.rb/issues/8)
  - [#14](https://github.com/RickHPotter/finance.rb/issues/14)
  - [#15](https://github.com/RickHPotter/finance.rb/issues/15)

- Subtasks:
  - ✅ Use TDD approach; create the tests before.
  - ✅ Create Model that will reference a entity_transaction and generate a money_transaction.
  - ✅ The table should include the fields: [id, timestamps,
       exchange_type (monetary, non-monetary), amount_to_be_returned, amount_returned].
  - ✅ CardTransaction should `has_many :entity_transactions`,
       EntityTransaction should `has_many :exchanges`,
       Exchange should `belongs_to :money_transaction, optional: true`.
  - ✅ One entity_transaction should be created for every entity card_transaction.
  - ✅ One exchange should be created for every paying entity_transaction.
- Extra:
  - ✅ Made a join table for Transaction and Category (like EntityTransaction).
  - ✅ Made a Concern for CategoryTransaction (like EntityTransactable).
  - ✅ Made an Installable Concern to be used by both Transactions.
  - ✅ Made possible to change the amount of installments in a Transactable.
  - ⌛ Added EntityTransaction specs for is_payer = true and status = :pending.
  - ⌛ Added CategoryTransaction specs for callbacks.

## GAARA-07/be-06: Refine EntityTransaction and Exchange Models

- Issues:
  - [#8](https://github.com/RickHPotter/finance.rb/issues/8)

- Subtasks:
  - ⌛ Use TDD approach; create the tests before.
  - ⌛ One money_transaction should be created for every monetary exchange,
       with a builtin `category = 'Exchange Return'` and no entity_transaction.
  - ⌛ Removing or updating one of the models that belong to the exchange flow
       [card_transaction -> entity_transaction / exchange -> money_transaction]
       should also reflect on the corresponding money_transaction.
- Extra:
  - ⌛ Added factory and model-based specs for Installment.
  - ⌛ Added Exchange specs for both exchange_types.

## GAARA-08/be-07: Refine Seeds and fix possible bugs found at this stage

- Subtasks:
  - ⌛ Refine seeds to include all models.
  - ⌛ Fix possible bugs found at this stage.
  - ⌛ Review current specs and refactor if possible.
- Extra:
  - ⌛ Made possible to change FK of CardTransaction (should create/use another money_transaction).
  - ⌛ Made possible to change FK of Investment (should create/use another money_transaction).

## GAARA-09/fe-01: Refine AutocompleteSelect

- Issues:
  - [#10](https://github.com/RickHPotter/finance.rb/issues/10)

- Subtasks:
  - ⌛ Use TDD approach; create the tests before.
  - ⌛ When typing, the first option should be rendered in the input, but with font-light.
  - ⌛ Add option to use a round-colour or an icon or a picture on the far-left
  - ⌛ Deny an option if already chosen in a previous select (Category, i.e.)

## GAARA-10/fe-02: Create MultiCheckBoxComponent

- Issues:
  - [#11](https://github.com/RickHPotter/finance.rb/issues/11)

- Subtasks:
  - ⌛ Use TDD approach; create the tests before.
  - ⌛ Grant many options and add turbo-frame to it as these options are relevant.

## GAARA-11/fe-03: Refine TabComponent

- Issues:
  - [#12](https://github.com/RickHPotter/finance.rb/issues/12)

- Subtasks:
  - ⌛ Use TDD approach; create the tests before.
  - ⌛ Make the Item Struct cleaner on the Controller.
  - ⌛ Pass in dependents as other structure other than itself (MultiCheckBoxComponent).
  - ⌛ Deny an option if already chosen in a previous select (Category, i.e.)

## GAARA-12/fe-04: Finish the MVP / Finish remaining Request and System Specs

- Issues:
  - [#13](https://github.com/RickHPotter/finance.rb/issues/13)

- Subtasks:
  - ⌛ Use TDD approach (better late than never).
  - ⌛ Remove Entity from the form.
  - ⌛ Create a Component for the refMonthYear.
  - ⌛ Start a draft on the EntityTransaction and Exchange references.
