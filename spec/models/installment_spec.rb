# frozen_string_literal: true

# == Schema Information
#
# Table name: installments
#
#  id                      :bigint           not null, primary key
#  starting_price          :integer          not null
#  price                   :integer          not null
#  number                  :integer          not null
#  month                   :integer          not null
#  year                    :integer          not null
#  installment_type        :string           not null
#  card_installments_count :integer          default(0)
#  cash_installments_count :integer          default(0)
#  card_transaction_id     :bigint
#  cash_transaction_id     :bigint
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#
require "rails_helper"

RSpec.describe Installment, type: :model do
  let!(:card_transaction) { create(:card_transaction) }
  let!(:subject) { card_transaction.card_installments.first }

  describe "[ activerecord validations ]" do
    context "( presence, uniqueness, etc )" do
      it "is valid with valid attributes" do
        expect(subject).to be_valid
      end

      %i[price card_installments_count cash_installments_count].each do |attribute|
        it { should validate_presence_of(attribute) }
      end
    end
  end
end
