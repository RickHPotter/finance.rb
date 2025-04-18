# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardInstallment, type: :model do
  let(:card_transaction) { create(:card_transaction, :random) }
  let(:subject) { card_transaction.card_installments.first }

  describe "[ activerecord validations ]" do
    context "( presence, uniqueness, etc )" do
      it "is valid with valid attributes" do
        expect(subject).to be_valid
        expect(subject.installment_type).to eq "CardInstallment"
      end

      %i[date price installment_type card_installments_count].each do |attribute|
        it { should validate_presence_of(attribute) }
      end
    end

    context "( associations )" do
      bto_models = %i[cash_transaction]

      bto_models.each { |model| it { should belong_to(model).optional } }
    end
  end
end

# == Schema Information
#
# Table name: installments
#
#  id                      :bigint           not null, primary key
#  balance                 :integer
#  card_installments_count :integer          default(0)
#  cash_installments_count :integer          default(0)
#  date                    :datetime         not null, indexed => [date_year, date_month]
#  date_month              :integer          not null, indexed => [date_year, date]
#  date_year               :integer          not null, indexed => [date_month, date]
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
#  idx_installments_year_month_date           (date_year,date_month,date)
#  index_installments_on_card_transaction_id  (card_transaction_id)
#  index_installments_on_cash_transaction_id  (cash_transaction_id)
#
# Foreign Keys
#
#  fk_rails_...  (card_transaction_id => card_transactions.id)
#  fk_rails_...  (cash_transaction_id => cash_transactions.id)
#
