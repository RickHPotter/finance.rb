# frozen_string_literal: true

require "rails_helper"

RSpec.describe CashInstallment, type: :model do
  let(:cash_transaction) { create(:cash_transaction, :random) }
  let(:subject) { cash_transaction.cash_installments.first }

  describe "[ activerecord validations ]" do
    context "( presence, uniqueness, etc )" do
      it "is valid with valid attributes" do
        expect(subject).to be_valid
        expect(subject.installment_type).to eq "CashInstallment"
      end

      %i[number date price installment_type cash_installments_count].each do |attribute|
        it { should validate_presence_of(attribute) }
      end
    end

    context "( associations )" do
      bt_models = %i[cash_transaction]

      bt_models.each { |model| it { should belong_to(model) } }
    end
  end
end

# == Schema Information
#
# Table name: installments
#
#  id                      :bigint           not null, primary key
#  card_installments_count :integer          default(0)
#  cash_installments_count :integer          default(0)
#  date                    :date             not null
#  date_month              :integer          not null, indexed => [date_year]
#  date_year               :integer          not null, indexed => [date_month]
#  installment_type        :string           not null
#  month                   :integer          not null
#  number                  :integer          not null
#  paid                    :boolean          default(FALSE)
#  price                   :integer          not null, indexed
#  starting_price          :integer          not null
#  year                    :integer          not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  card_transaction_id     :bigint           indexed
#  cash_transaction_id     :bigint           indexed
#
# Indexes
#
#  idx_installments_price                     (price)
#  idx_installments_year_month                (date_year,date_month)
#  index_installments_on_card_transaction_id  (card_transaction_id)
#  index_installments_on_cash_transaction_id  (cash_transaction_id)
#
# Foreign Keys
#
#  fk_rails_...  (card_transaction_id => card_transactions.id)
#  fk_rails_...  (cash_transaction_id => cash_transactions.id)
#
