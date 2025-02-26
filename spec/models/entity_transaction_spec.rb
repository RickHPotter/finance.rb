# frozen_string_literal: true

# == Schema Information
#
# Table name: entity_transactions
#
#  id                :bigint           not null, primary key
#  is_payer          :boolean          default(FALSE), not null
#  status            :integer          default("pending"), not null
#  price             :integer          default(0), not null
#  exchanges_count   :integer          default(0), not null
#  entity_id         :bigint           not null
#  transactable_type :string           not null
#  transactable_id   :bigint           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
require "rails_helper"

RSpec.describe EntityTransaction, type: :model do
  let!(:subject) { build(:entity_transaction, :random) }

  describe "[ activerecord validations ]" do
    context "( presence, uniqueness, etc )" do
      it "is valid with valid attributes" do
        expect(subject).to be_valid
      end

      %i[price].each do |attribute|
        it { should validate_presence_of(attribute) }
      end

      it { should validate_uniqueness_of(:entity_id).scoped_to(:transactable_type, :transactable_id) }
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
end
