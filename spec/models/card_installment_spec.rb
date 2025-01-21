# frozen_string_literal: true

# == Schema Information
#
# Table name: installments
#
#  id                      :bigint           not null, primary key
#  number                  :integer          not null
#  date                    :date             not null
#  month                   :integer          not null
#  year                    :integer          not null
#  starting_price          :integer          not null
#  price                   :integer          not null
#  paid                    :boolean          default(FALSE)
#  installment_type        :string           not null
#  card_installments_count :integer          default(0)
#  cash_installments_count :integer          default(0)
#  card_transaction_id     :bigint
#  cash_transaction_id     :bigint
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#
require "rails_helper"

RSpec.describe CardInstallment, type: :model do
  let!(:card_transaction) { create(:card_transaction, :random) }
  let!(:subject) { card_transaction.card_installments.first }

  describe "[ activerecord validations ]" do
    context "( presence, uniqueness, etc )" do
      it "is valid with valid attributes" do
        expect(subject).to be_valid
      end

      %i[price card_installments_count].each do |attribute|
        it { should validate_presence_of(attribute) }
      end
    end
  end
end
