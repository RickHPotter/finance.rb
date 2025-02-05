# frozen_string_literal: true

# == Schema Information
#
# Table name: user_cards
#
#  id                   :bigint           not null, primary key
#  active               :boolean          default(TRUE), not null
#  credit_limit         :integer          not null
#  current_closing_date :date             not null
#  current_due_date     :date             not null
#  days_until_due_date  :integer          not null
#  min_spend            :integer          not null
#  user_card_name       :string           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  card_id              :bigint           not null
#  user_id              :bigint           not null
#
# Indexes
#
#  index_user_cards_on_card_id         (card_id)
#  index_user_cards_on_user_card_name  (user_card_name) UNIQUE
#  index_user_cards_on_user_id         (user_id)
#
require "rails_helper"

RSpec.describe UserCard, type: :model do
  let!(:subject) { build(:user_card, :random) }

  describe "[ activerecord validations ]" do
    context "( presence, uniqueness, etc )" do
      it "is valid with valid attributes" do
        expect(subject).to be_valid
      end

      %i[min_spend credit_limit].each do |attribute|
        it { should validate_presence_of(attribute) }
      end

      it { should validate_uniqueness_of(:user_card_name).scoped_to(:user_id) }
    end

    context "( associations )" do
      bt_models = %i[user card]
      hm_models = %i[card_transactions]

      bt_models.each { |model| it { should belong_to(model) } }
      hm_models.each { |model| it { should have_many(model) } }
    end
  end

  describe "[ business logic ]" do
    context "( callbacks )" do
      it "assigns the correct current_closing_date given past current_due_date" do
        current_due_date = Date.current.beginning_of_year - 1.year
        subject.update(current_closing_date: nil, current_due_date:, days_until_due_date: 7)
        expect(subject.current_closing_date).to eq(subject.current_due_date - 7.days)
      end

      it "assigns the correct current_closing_date given future current_due_date" do
        current_due_date = Date.current.beginning_of_year + 1.year
        subject.update(current_closing_date: nil, current_due_date:, days_until_due_date: 7)
        expect(subject.current_closing_date).to eq(subject.current_due_date - 7.days)
      end
    end
  end
end
