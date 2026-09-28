# frozen_string_literal: true

require "rails_helper"

RSpec.describe CategoryTransaction, type: :model do
  let(:subject) { build(:category_transaction, :random) }

  describe "[ activerecord validations ]" do
    context "( presence, uniqueness, etc )" do
      it "is valid with valid attributes" do
        expect(subject).to be_valid
      end

      it { should validate_uniqueness_of(:category_id).scoped_to(:transactable_type, :transactable_id) }
    end

    context "( associations )" do
      bt_models = %i[category transactable]

      bt_models.each { |model| it { should belong_to(model) } }
    end
  end

  describe "[ hierarchy assignment ]" do
    let(:user) { create(:user, :random) }
    let(:parent) { create(:category, :parent_category, user:) }
    let(:child) { create(:category, :child_category, user:, parent_category: parent) }
    let(:cash_transaction) { create(:cash_transaction, :random, user:) }

    it "allows assigning a parent category to a transaction" do
      ct = build(:category_transaction, category: parent, transactable: cash_transaction)
      expect(ct).to be_valid
    end

    it "allows assigning a subcategory to a transaction" do
      ct = build(:category_transaction, category: child, transactable: cash_transaction)
      expect(ct).to be_valid
    end
  end
end

# == Schema Information
#
# Table name: category_transactions
# Database name: primary
#
#  id                :bigint           not null, primary key
#  transactable_type :string           not null, uniquely indexed => [category_id, transactable_id], indexed => [transactable_id]
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  category_id       :bigint           not null, indexed, uniquely indexed => [transactable_type, transactable_id]
#  transactable_id   :bigint           not null, uniquely indexed => [category_id, transactable_type], indexed => [transactable_type]
#
# Indexes
#
#  index_category_transactions_on_category_id    (category_id)
#  index_category_transactions_on_composite_key  (category_id,transactable_type,transactable_id) UNIQUE
#  index_category_transactions_on_transactable   (transactable_type,transactable_id)
#
# Foreign Keys
#
#  fk_rails_...  (category_id => categories.id)
#
