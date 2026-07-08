# frozen_string_literal: true

require "rails_helper"

RSpec.describe EntityTransaction, type: :model do
  let(:subject) { build(:entity_transaction, :random) }

  describe "[ activerecord validations ]" do
    context "( presence, uniqueness, etc )" do
      it "is valid with valid attributes" do
        expect(subject).to be_valid
      end

      %i[price].each do |attribute|
        it { should validate_presence_of(attribute) }
      end

      it { should validate_uniqueness_of(:entity_id).scoped_to(:transactable_type, :transactable_id) }
      it { should validate_numericality_of(:loan_return_percentage).is_greater_than_or_equal_to(0) }
    end

    context "( associations )" do
      bt_models = %i[entity transactable]
      hm_models = %i[exchanges]
      na_models = %i[exchanges]

      bt_models.each { |model| it { should belong_to(model) } }
      hm_models.each { |model| it { should have_many(model) } }
      na_models.each { |model| it { should accept_nested_attributes_for(model) } }

      it { should define_enum_for(:status).with_values(pending: 0, finished: 1) }
    end
  end

  describe "[ business logic ]" do
    it "calculates the row return percentage against the transaction total" do
      transaction = build(:cash_transaction, price: -27_000)
      entity_transaction = build(:entity_transaction, transactable: transaction, price: 31_000, price_to_be_returned: 31_000)

      expect(entity_transaction.calculated_loan_return_percentage).to eq(114.8148.to_d)
    end
  end
end

# == Schema Information
#
# Table name: entity_transactions
# Database name: primary
#
#  id                     :bigint           not null, primary key
#  exchanges_count        :integer          default(0), not null
#  is_payer               :boolean          default(FALSE), not null
#  loan_return_percentage :decimal(10, 4)   default(100.0), not null
#  price                  :integer          default(0), not null
#  price_to_be_returned   :integer          default(0), not null
#  status                 :integer          default("pending"), not null
#  transactable_type      :string           not null, uniquely indexed => [entity_id, transactable_id], indexed => [transactable_id]
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  entity_id              :bigint           not null, uniquely indexed => [transactable_type, transactable_id], indexed
#  transactable_id        :bigint           not null, uniquely indexed => [entity_id, transactable_type], indexed => [transactable_type]
#
# Indexes
#
#  index_entity_transactions_on_composite_key  (entity_id,transactable_type,transactable_id) UNIQUE
#  index_entity_transactions_on_entity_id      (entity_id)
#  index_entity_transactions_on_transactable   (transactable_type,transactable_id)
#
# Foreign Keys
#
#  fk_rails_...  (entity_id => entities.id)
#
