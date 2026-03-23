# frozen_string_literal: true

require "rails_helper"

RSpec.describe DuePaymentsNotifier do
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
  end
end
