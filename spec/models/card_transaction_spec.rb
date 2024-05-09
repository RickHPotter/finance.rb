# frozen_string_literal: true

# == Schema Information
#
# Table name: card_transactions
#
#  id                 :bigint           not null, primary key
#  ct_description     :string           not null
#  ct_comment         :text
#  date               :date             not null
#  month              :integer          not null
#  year               :integer          not null
#  starting_price     :decimal(, )      not null
#  price              :decimal(, )      not null
#  installments_count :integer          default(0), not null
#  user_id            :bigint           not null
#  user_card_id       :bigint           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
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

      %i[ct_description date month year starting_price price installments_count].each do |attribute|
        it { should validate_presence_of(attribute) }
      end
    end

    context "( associations )" do
      bt_models = %i[user user_card]
      hm_models = %i[categories category_transactions entities entity_transactions installments]
      na_models = %i[category_transactions entity_transactions installments]

      bt_models.each { |model| it { should belong_to(model) } }
      hm_models.each { |model| it { should have_many(model) } }
      na_models.each { |model| it { should accept_nested_attributes_for(model) } }
    end
  end

  describe "[ business logic ]" do
    context "( public methods )" do
      it "returns full_description" do
        expect(subject.to_s).to eq(subject.ct_description)
      end
    end
  end
end
