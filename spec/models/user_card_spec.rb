# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserCard, type: :model do
  let(:subject) { build(:user_card, :random) }

  describe "[ activerecord validations ]" do
    context "( presence, uniqueness, etc )" do
      it "is valid with valid attributes" do
        expect(subject).to be_valid
      end

      %i[min_spend credit_limit due_date_day days_until_due_date].each do |attribute|
        it { should validate_presence_of(attribute) }
      end

      it { should validate_uniqueness_of(:user_card_name).scoped_to(%i[user_id card_id]) }
    end

    context "( associations )" do
      bt_models = %i[user card]
      hm_models = %i[card_transactions card_installments card_installments_invoices cash_transactions references]

      bt_models.each { |model| it { should belong_to(model) } }
      hm_models.each { |model| it { should have_many(model) } }
    end
  end

  describe "[ business logic ]" do
    it "calculates the next reference date based on due_date_day and days_until_due_date" do
      subject.due_date_day = 10
      subject.days_until_due_date = 5

      expect(subject.calculate_reference_date(Date.new(2026, 3, 3))).to eq(Date.new(2026, 3, 10))
      expect(subject.calculate_reference_date(Date.new(2026, 3, 8))).to eq(Date.new(2026, 4, 10))
    end

    it "finds or creates a matching reference for a date" do
      subject.save!

      reference = subject.find_or_create_reference_for(Date.new(2026, 3, 3))

      expect(reference).to be_persisted
      expect(reference.user_card).to eq(subject)
      expect(subject.find_or_create_reference_for(Date.new(2026, 3, 3))).to eq(reference)
    end
  end
end

# == Schema Information
#
# Table name: user_cards
# Database name: primary
#
#  id                      :bigint           not null, primary key
#  active                  :boolean          default(TRUE), not null
#  card_transactions_count :integer          default(0), not null
#  card_transactions_total :integer          default(0), not null
#  credit_limit            :integer          not null
#  days_until_due_date     :integer          not null
#  due_date_day            :integer          default(1), not null
#  min_spend               :integer          not null
#  user_card_name          :string           not null, uniquely indexed => [user_id, card_id]
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  card_id                 :bigint           not null, indexed, uniquely indexed => [user_id, user_card_name]
#  user_id                 :bigint           not null, uniquely indexed => [card_id, user_card_name], indexed
#
# Indexes
#
#  index_user_cards_on_card_id           (card_id)
#  index_user_cards_on_on_composite_key  (user_id,card_id,user_card_name) UNIQUE
#  index_user_cards_on_user_id           (user_id)
#
