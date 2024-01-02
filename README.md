<!--toc:start-->
- [INTRODUCTION](#introduction)
- [SPRINT PLANNING I: GAARA](#sprint-planning-i-gaara)
  - [GAARA-01/be-01: Finish late Model Specs](#gaara-01be-01-finish-late-model-specs)
  - [GAARA-02/be-02: Create models that revolve around MoneyTransaction](#gaara-02be-02-create-models-that-revolve-around-moneytransaction)
  - [GAARA-03/be-03: Implement 'buy now, pay later' system](#gaara-03be-03-implement-buy-now-pay-later-system)
  - [GAARA-04/app-01: Update stack and add Docker](#gaara-04app-01-update-stack-and-add-docker)
  - [GAARA-05/be-04: Create TransactionParticipant Model; Installments in MoneyTransaction](#gaara-05be-04-create-transactionparticipant-model-installments-in-moneytransaction)
  - [GAARA-06/be-05: Create Exchange Model](#gaara-06be-05-create-exchange-model)
  - [GAARA-07/be-06: Refine TransactionParticipant and Exchange Models](#gaara-07be-06-refine-transactionparticipant-and-exchange-models)
  - [GAARA-08/be-07: Calculate transactions based on Exchange](#gaara-08be-07-calculate-transactions-based-on-exchange)
  - [GAARA-09/fe-01: Refine AutocompleteSelect](#gaara-09fe-01-refine-autocompleteselect)
  - [GAARA-10/fe-02: Create MultiCheckBoxComponent](#gaara-10fe-02-create-multicheckboxcomponent)
  - [GAARA-11/fe-03: Refine TabComponent](#gaara-11fe-03-refine-tabcomponent)
  - [GAARA-12/fe-04: Finish Component Specs for the remaining and some form TODOs](#gaara-12fe-04-finish-component-specs-for-the-remaining-and-some-form-todos)
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

## GAARA-05/be-04: Create TransactionParticipant Model; Installments in MoneyTransaction

- Subtasks:
  - ⌛ Use TDD approach; create the tests before.
  - ⌛ Create Model that links a ([card/money]_)transaction to a (number of) entit(ies).
  - ⌛ The table should include the fields: [id, timestamps, is_payer as boolean,
       amount_to_be_returned and amount_returned as decimal, status (pending, finished)].
  - ⌛ Remove entity_id from (Card/Money)Transaction.

## GAARA-06/be-05: Create Exchange Model

- Subtasks:
  - ⌛ Use TDD approach; create the tests before.
  - ⌛ Create Model that will reference a transaction_participant.
  - ⌛ TransactionParticipant should `has_many exchanges, optional: true`.
  - ⌛ The table should include the fields: [id, timestamps,
       reason ('currency' card <-> money, 'favour' non-monetary, 'time' same currency),
       exchange_type (monetary, non-monetary), amount (default 0 - non-monetary)].
  - ⌛ Implement in (Card/Money)Transaction the `has_many :exchanges, optional: true`.
  - ⌛ Exchange Model should have a `belongs_to :exchangable, polymorphic: true`.

## GAARA-07/be-06: Refine TransactionParticipant and Exchange Models

- Subtasks:
  - ⌛ Use TDD approach; create the tests before.
  - ⌛ When a transaction_participant is a payer:
    - 1 ⌛ It should generate `is_payer: true, status: 'pending'`.
    - 2 ⌛ The amount_to_be_returned and amount_returned should be filled in.
    - 3 ⌛ An Exchange should be created for this transaction_participant.
    - 4 ⌛ The returning transaction should reference this exchange.
    - 5 ⌛ This new transaction should have a builtin `category = 'Exchange Return'`,
          and no transaction_participant.
  - ⌛ When a transaction_participant is not a payer:
    - 1 ⌛ The transaction_participant should have `is_payer: false, status = 'finished'`.

## GAARA-08/be-07: Calculate transactions based on Exchange

- Subtasks:
  - ⌛ Use TDD approach; create the tests before.
  - ⌛ New money_transactions should be created automatically based on Exchange.
  - ⌛ Removing should also impact these money_transactions.

## GAARA-09/fe-01: Refine AutocompleteSelect

- Subtasks:
  - ⌛ Use TDD approach; create the tests before.
  - ⌛ When typing, the first option should be rendered in the input, but with font-light.
  - ⌛ Add option to use a round-colour or an icon or a picture on the far-left
  - ⌛ Deny an option if already chosen in a previous select (Category, i.e.)

## GAARA-10/fe-02: Create MultiCheckBoxComponent

- Subtasks:
  - ⌛ Use TDD approach; create the tests before.
  - ⌛ Grant many options and add turbo-frame to it as these options are relevant.

## GAARA-11/fe-03: Refine TabComponent

- Subtasks:
  - ⌛ Use TDD approach; create the tests before.
  - ⌛ Make the Item Struct cleaner on the Controller.
  - ⌛ Pass in dependents as other structure other than itself (MultiCheckBoxComponent).
  - ⌛ Deny an option if already chosen in a previous select (Category, i.e.)

## GAARA-12/fe-04: Finish Component Specs for the remaining and some form TODOs

- Subtasks:
  - ⌛ Use TDD approach (better late than never).
  - ⌛ Remove Entity from the form.
  - ⌛ Create a Component for the refMonthYear.
  - ⌛ Start a draft on the TransactionParticipant and Exchange references.
