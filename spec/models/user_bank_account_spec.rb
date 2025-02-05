# frozen_string_literal: true

# == Schema Information
#
# Table name: user_bank_accounts
#
#  id             :bigint           not null, primary key
#  account_number :integer
#  active         :boolean          default(TRUE), not null
#  agency_number  :integer
#  balance        :integer          default(0), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  bank_id        :bigint           not null
#  user_id        :bigint           not null
#
# Indexes
#
#  index_user_bank_accounts_on_bank_id  (bank_id)
#  index_user_bank_accounts_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (bank_id => banks.id)
#  fk_rails_...  (user_id => users.id)
#
require "rails_helper"

RSpec.describe UserBankAccount, type: :model do
  let!(:subject) { build(:user_bank_account, :random) }

  describe "[ activerecord validations ]" do
    context "( presence, uniqueness, etc )" do
      it "is valid with valid attributes" do
        expect(subject).to be_valid
      end

      it { should validate_presence_of(:balance) }
      it { should validate_uniqueness_of(:bank_id).scoped_to(:agency_number, :account_number) }

      context "( associations )" do
        bt_models = %i[user bank]
        hm_models = %i[investments]

        bt_models.each { |model| it { should belong_to(model) } }
        hm_models.each { |model| it { should have_many(model) } }
      end
    end
  end
end
