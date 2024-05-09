# frozen_string_literal: true

# == Schema Information
#
# Table name: money_transactions
#
#  id                     :bigint           not null, primary key
#  mt_description         :string           not null
#  mt_comment             :text
#  date                   :date             not null
#  month                  :integer          not null
#  year                   :integer          not null
#  starting_price         :decimal(, )      not null
#  price                  :decimal(, )      not null
#  paid                   :boolean          default(FALSE)
#  money_transaction_type :string
#  user_id                :bigint           not null
#  user_card_id           :bigint
#  user_bank_account_id   :bigint
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
require "rails_helper"

RSpec.describe MoneyTransaction, type: :model do
  let(:subject) { build(:money_transaction, :random) }

  describe "[ activerecord validations ]" do
    context "( presence, uniqueness, etc )" do
      it "is valid with valid attributes" do
        expect(subject).to be_valid
      end

      %i[mt_description date price].each do |attribute|
        it { should validate_presence_of(attribute) }
      end
    end

    context "( associations )" do
      ob_models = %i[user_card user_bank_account]
      bt_models = %i[user]
      hm_models = %i[installments investments exchanges category_transactions categories]
      na_models = %i[category_transactions]

      ob_models.each { |model| it { should belong_to(model).optional } }
      bt_models.each { |model| it { should belong_to(model) } }
      hm_models.each { |model| it { should have_many(model) } }
      na_models.each { |model| it { should accept_nested_attributes_for(model) } }
    end
  end

  describe "[ business logic ]" do
    context "( public methods )" do
      it "returns full_description" do
        expect(subject.to_s).to eq(subject.mt_description)
      end
    end
  end
end
