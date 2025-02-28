# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardTransaction, type: :model do
  let(:user_card) { create(:user_card, :random) }
  let(:card_transaction) { build(:card_transaction, :random, user_card:) }

  describe "[ activerecord validations ]" do
    context "( presence, uniqueness, etc )" do
      it "is valid with valid attributes" do
        expect(card_transaction).to be_valid
      end

      %i[description date price card_installments_count].each do |attribute|
        it { should validate_presence_of(attribute) }
      end
    end

    context "( associations )" do
      bt_models = %i[user user_card]
      bto_models = %i[advance_cash_transaction]
      hm_models = %i[categories category_transactions entities entity_transactions card_installments]
      na_models = %i[category_transactions entity_transactions card_installments]

      bt_models.each { |model| it { should belong_to(model) } }
      bto_models.each { |model| it { should belong_to(model).optional } }
      hm_models.each { |model| it { should have_many(model) } }
      na_models.each { |model| it { should accept_nested_attributes_for(model) } }
    end
  end
end

# == Schema Information
#
# Table name: card_transactions
#
#  id                          :bigint           not null, primary key
#  card_installments_count     :integer          default(0), not null
#  comment                     :text
#  date                        :datetime         not null
#  description                 :string           not null, indexed
#  month                       :integer          not null
#  paid                        :boolean          default(FALSE)
#  price                       :integer          not null, indexed
#  starting_price              :integer          not null
#  year                        :integer          not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  advance_cash_transaction_id :bigint           indexed
#  user_card_id                :bigint           not null, indexed
#  user_id                     :bigint           not null, indexed
#
# Indexes
#
#  idx_card_transactions_description_trgm                  (description) USING gin
#  idx_card_transactions_price                             (price)
#  index_card_transactions_on_advance_cash_transaction_id  (advance_cash_transaction_id)
#  index_card_transactions_on_user_card_id                 (user_card_id)
#  index_card_transactions_on_user_id                      (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (advance_cash_transaction_id => cash_transactions.id)
#  fk_rails_...  (user_card_id => user_cards.id)
#  fk_rails_...  (user_id => users.id)
#
