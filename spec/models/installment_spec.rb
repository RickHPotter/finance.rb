# frozen_string_literal: true

# == Schema Information
#
# Table name: installments
#
#  id                      :bigint           not null, primary key
#  starting_price          :decimal(, )      not null
#  price                   :decimal(, )      not null
#  number                  :integer          not null
#  month                   :integer          not null
#  year                    :integer          not null
#  card_transactions_count :integer          default(0), not null
#  card_transaction_id     :bigint           not null
#  money_transaction_id    :bigint           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#
require "rails_helper"

RSpec.describe Installment, type: :model do
  # let(:card_transaction) { create(:card_transaction, :random, date: Date.current) }
  # let(:money_transaction) { create(:money_transaction, :random, date: Date.current) }
  # let(:installment) { card_transaction.installments.first }
  #
  # shared_examples "installments cop" do
  #   it "creates the expected amount of installments" do
  #     expect(card_transaction.installments_count).to eq card_transaction.installments.count
  #     expect(money_transaction.installments_count).to eq money_transaction.installments.count
  #   end
  #
  #   it "applies the right relationship to the transaction" do
  #     card_transaction.installments.each do |installment|
  #       expect(installment.installable_id).to eq card_transaction.id
  #       expect(installment.installable_type).to eq card_transaction.class.name
  #     end
  #
  #     money_transaction.installments.each do |installment|
  #       expect(installment.installable_id).to eq money_transaction.id
  #       expect(installment.installable_type).to eq money_transaction.class.name
  #     end
  #   end
  #
  #   it "sums the installments correctly" do
  #     expect(card_transaction.installments.sum(:price).round(2)).to be_within(0.01).of card_transaction.price
  #     expect(money_transaction.installments.sum(:price).round(2)).to be_within(0.01).of money_transaction.price
  #   end
  # end
  #
  # describe "[ business logic ]" do
  #   context "( when installments_count is 1 )" do
  #     include_examples "installments cop"
  #   end
  #
  #   context "( when installments_count is 2 )" do
  #     before do
  #       card_transaction.update(installments: build_list(:installment, 2, price: (card_transaction.price / 2).round(2)), date: Date.current)
  #       money_transaction.update(installments: build_list(:installment, 2, price: (money_transaction.price / 2).round(2)), date: Date.current)
  #     end
  #
  #     include_examples "installments cop"
  #   end
  #
  #   context "( when installments_count is 3 )" do
  #     before do
  #       card_transaction.update(installments: build_list(:installment, 3, price: (card_transaction.price / 3).round(2)), date: Date.current)
  #       money_transaction.update(installments: build_list(:installment, 3, price: (money_transaction.price / 3).round(2)), date: Date.current)
  #     end
  #
  #     include_examples "installments cop"
  #   end
  # end
end
