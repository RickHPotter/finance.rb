# frozen_string_literal: true

require "rails_helper"

RSpec.describe DuePaymentsNotifier do
  around do |example|
    ActionMailer::Base.deliveries.clear
    example.run
    ActionMailer::Base.deliveries.clear
  end

  describe "#call" do
    it "notifies only main-context due installments" do
      user = create(:user, :random)
      bank = create(:bank, :random)
      user_bank_account = create(:user_bank_account, user:, bank:)
      create(:push_subscription, user:)

      today = Time.zone.today

      create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        description: "Main due",
        cash_installments: [
          build(:cash_installment, number: 1, date: today, month: today.month, year: today.year, price: 100, paid: false)
        ]
      )

      derived_context = create(:context, user:, name: "Notifier Isolation", source_context: user.main_context)
      create(
        :cash_transaction,
        user:,
        context: derived_context,
        user_bank_account:,
        description: "Derived due",
        cash_installments: [
          build(:cash_installment, number: 1, date: today, month: today.month, year: today.year, price: 200, paid: false)
        ]
      )

      notifier = described_class.new

      expect(notifier).to receive(:payload_send).once do |title:, body:, url:, push_subscription:|
        expect(title).to be_present
        expect(body).to include("Main due")
        expect(body).not_to include("Derived due")
        expect(url).to be_present
        expect(push_subscription.user).to eq(user)
      end

      notifier.call
    end

    it "emails overdue, today, and tomorrow unpaid installments as one digest" do
      user = create(:user, :random, locale: "en")
      bank = create(:bank, :random)
      user_bank_account = create(:user_bank_account, user:, bank:)
      today = Time.zone.today

      create_transaction_with_installment(user:, user_bank_account:, attributes: { description: "Overdue rent", date: today - 2.days, price: -120_000 })
      create_transaction_with_installment(user:, user_bank_account:, attributes: { description: "Today internet", date: today, price: -9_900 })
      create_transaction_with_installment(user:, user_bank_account:, attributes: { description: "Tomorrow card", date: today + 1.day, price: -45_000 })
      create_transaction_with_installment(user:, user_bank_account:, attributes: { description: "Paid old bill", date: today - 1.day, price: -10_000, paid: true })

      described_class.new.call

      mail = ActionMailer::Base.deliveries.last

      expect(mail).to be_present
      expect(mail.to).to eq([ user.email ])
      expect(mail.subject).to include("30/Fev payment reminder")
      expect(mail.html_part.body.encoded).to include("High Alert: overdue")
      expect(mail.html_part.body.encoded).to include("Overdue rent")
      expect(mail.html_part.body.encoded).to include("Today internet")
      expect(mail.html_part.body.encoded).to include("Tomorrow card")
      expect(mail.html_part.body.encoded).to include("gmail-blend-screen")
      expect(mail.html_part.body.encoded).to include("-webkit-text-fill-color: #ffffff")
      expect(mail.html_part.body.encoded).not_to include("Paid old bill")
    end

    it "does not email derived-context installments" do
      user = create(:user, :random, locale: "en")
      bank = create(:bank, :random)
      user_bank_account = create(:user_bank_account, user:, bank:)
      today = Time.zone.today
      derived_context = create(:context, user:, name: "Derived", source_context: user.main_context)

      create_transaction_with_installment(user:, user_bank_account:, attributes: { description: "Main reminder", date: today, price: -1_000 })
      create_transaction_with_installment(user:, user_bank_account:,
                                          attributes: { description: "Derived reminder", date: today, price: -2_000, context: derived_context })

      described_class.new.call

      body = ActionMailer::Base.deliveries.last.html_part.body.encoded

      expect(body).to include("Main reminder")
      expect(body).not_to include("Derived reminder")
    end

    it "temporarily sends reminders only to the first user" do
      first_user = create(:user, :random, locale: "en")
      second_user = create(:user, :random, locale: "en")
      today = Time.zone.today

      create_transaction_with_installment(
        user: first_user,
        user_bank_account: create(:user_bank_account, user: first_user, bank: create(:bank, :random)),
        attributes: { description: "First user reminder", date: today, price: -1_000 }
      )
      create_transaction_with_installment(
        user: second_user,
        user_bank_account: create(:user_bank_account, user: second_user, bank: create(:bank, :random)),
        attributes: { description: "Second user reminder", date: today, price: -2_000 }
      )

      described_class.new.call

      expect(ActionMailer::Base.deliveries.map(&:to)).to eq([ [ first_user.email ] ])
      expect(ActionMailer::Base.deliveries.last.html_part.body.encoded).to include("First user reminder")
      expect(ActionMailer::Base.deliveries.last.html_part.body.encoded).not_to include("Second user reminder")
    end

    it "does not email when only tomorrow installments exist" do
      user = create(:user, :random, locale: "en")
      today = Time.zone.today

      create_transaction_with_installment(
        user:,
        user_bank_account: create(:user_bank_account, user:, bank: create(:bank, :random)),
        attributes: { description: "Tomorrow only", date: today + 1.day, price: -1_000 }
      )

      described_class.new.call

      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "sends one push notification for overdue installments" do
      user = create(:user, :random, locale: "en")
      bank = create(:bank, :random)
      user_bank_account = create(:user_bank_account, user:, bank:)
      expected_push_subscription = create(:push_subscription, user:)
      today = Time.zone.today

      create_transaction_with_installment(user:, user_bank_account:, attributes: { description: "Old rent", date: today - 2.days, price: -1_000 })
      create_transaction_with_installment(user:, user_bank_account:, attributes: { description: "Older internet", date: today - 1.day, price: -2_000 })

      notifier = described_class.new

      expect(notifier).to receive(:payload_send).once do |title:, body:, url:, push_subscription:, urgency:|
        expect(title).to be_present
        expect(body).to eq("You have 2 overdue payments")
        expect(url).to be_present
        expect(push_subscription).to eq(expected_push_subscription)
        expect(urgency).to eq("high")
      end

      notifier.call
    end
  end

  def create_transaction_with_installment(user:, user_bank_account:, attributes:)
    date = attributes.fetch(:date)
    price = attributes.fetch(:price)

    create(
      :cash_transaction,
      user:,
      context: attributes.fetch(:context, user.main_context),
      user_bank_account:,
      description: attributes.fetch(:description),
      date:,
      month: date.month,
      year: date.year,
      price:,
      cash_installments: [
        build(:cash_installment, number: 1, date:, month: date.month, year: date.year, price:, paid: attributes.fetch(:paid, false))
      ]
    )
  end
end
