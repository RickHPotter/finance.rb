# frozen_string_literal: true

require "rails_helper"

RSpec.describe CashTransaction, type: :model do
  let(:subject) { build(:cash_transaction, :random) }

  describe "[ activerecord validations ]" do
    context "( presence, uniqueness, etc )" do
      it "is valid with valid attributes" do
        expect(subject).to be_valid
      end

      %i[description price cash_installments_count].each do |attribute|
        it { should validate_presence_of(attribute) }
      end
    end

    context "( associations )" do
      bt_models = %i[user]
      bto_models = %i[user_card user_bank_account]
      hm_models = %i[card_installments investments exchanges cash_installments category_transactions categories entity_transactions entities]
      na_models = %i[category_transactions entity_transactions]

      bt_models.each { |model| it { should belong_to(model) } }
      bto_models.each { |model| it { should belong_to(model).optional } }
      hm_models.each { |model| it { should have_many(model) } }
      na_models.each { |model| it { should accept_nested_attributes_for(model) } }
    end
  end
end

# == Schema Information
#
# Table name: cash_transactions
#
#  id                      :bigint           not null, primary key
#  cash_installments_count :integer          default(0), not null
#  cash_transaction_type   :string
#  comment                 :text
#  date                    :datetime         not null
#  description             :string           not null
#  month                   :integer          not null
#  paid                    :boolean          default(FALSE)
#  price                   :integer          not null
#  starting_price          :integer          not null
#  year                    :integer          not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  user_bank_account_id    :bigint           indexed
#  user_card_id            :bigint           indexed
#  user_id                 :bigint           not null, indexed
#
# Indexes
#
#  index_cash_transactions_on_user_bank_account_id  (user_bank_account_id)
#  index_cash_transactions_on_user_card_id          (user_card_id)
#  index_cash_transactions_on_user_id               (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_bank_account_id => user_bank_accounts.id)
#  fk_rails_...  (user_card_id => user_cards.id)
#  fk_rails_...  (user_id => users.id)
#
