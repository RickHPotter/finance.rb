# frozen_string_literal: true

# == Schema Information
#
# Table name: cards
#
#  id         :bigint           not null, primary key
#  card_name  :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  bank_id    :bigint           not null
#
# Indexes
#
#  index_cards_on_bank_id    (bank_id)
#  index_cards_on_card_name  (card_name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (bank_id => banks.id)
#
require "rails_helper"

RSpec.describe Card, type: :model do
  let!(:subject) { build(:card, :random) }

  describe "[ activerecord validations ]" do
    context "( presence, uniqueness, etc )" do
      it "is valid with valid attributes" do
        expect(subject).to be_valid
      end

      %i[card_name].each do |attribute|
        it { should validate_presence_of(attribute) }
        it { should validate_uniqueness_of(attribute) }
      end
    end

    context "( associations )" do
      bt_models = %i[bank]
      hm_models = %i[user_cards]

      bt_models.each { |model| it { should belong_to(model) } }
      hm_models.each { |model| it { should have_many(model) } }
    end
  end
end
