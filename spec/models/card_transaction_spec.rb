# frozen_string_literal: true

# == Schema Information
#
# Table name: card_transactions
#
#  id                          :bigint           not null, primary key
#  description                 :string           not null
#  comment                     :text
#  date                        :date             not null
#  month                       :integer          not null
#  year                        :integer          not null
#  starting_price              :integer          not null
#  price                       :integer          not null
#  card_installments_count     :integer          default(0), not null
#  user_id                     :bigint           not null
#  user_card_id                :bigint           not null
#  advance_cash_transaction_id :bigint
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#
require "rails_helper"

RSpec.describe CardTransaction, type: :model do
  let!(:user_card) { build(:user_card, :random) }
  let!(:card_transaction) { build(:card_transaction, :random, user_card:) }

  describe "[ activerecord validations ]" do
    context "( presence, uniqueness, etc )" do
      it "is valid with valid attributes" do
        expect(card_transaction).to be_valid
      end

      %i[description date month year starting_price price card_installments_count].each do |attribute|
        it { should validate_presence_of(attribute) }
      end
    end

    context "( associations )" do
      bt_models = %i[user user_card]
      hm_models = %i[categories category_transactions entities entity_transactions card_installments]
      na_models = %i[category_transactions entity_transactions card_installments]

      bt_models.each { |model| it { should belong_to(model) } }
      hm_models.each { |model| it { should have_many(model) } }
      na_models.each { |model| it { should accept_nested_attributes_for(model) } }
    end
  end
end
