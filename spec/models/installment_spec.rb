# frozen_string_literal: true

# == Schema Information
#
# Table name: installments
#
#  id                   :bigint           not null, primary key
#  starting_price       :decimal(, )      not null
#  price                :decimal(, )      not null
#  number               :integer          not null
#  month                :integer          not null
#  year                 :integer          not null
#  installments_count   :integer          default(0), not null
#  card_transaction_id  :bigint           not null
#  money_transaction_id :bigint           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
require "rails_helper"

RSpec.describe Installment, type: :model do
  let!(:card_transaction) { create(:card_transaction) }
  let!(:subject) { card_transaction.installments.first }

  describe "[ activerecord validations ]" do
    context "( presence, uniqueness, etc )" do
      it "is valid with valid attributes" do
        expect(subject).to be_valid
      end

      %i[price installments_count].each do |attribute|
        it { should validate_presence_of(attribute) }
      end
    end
  end
end
