# frozen_string_literal: true

# == Schema Information
#
# Table name: category_transactions
#
#  id                :bigint           not null, primary key
#  category_id       :bigint           not null
#  transactable_type :string           not null
#  transactable_id   :bigint           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
require "rails_helper"

RSpec.describe CategoryTransaction, type: :model do
  let!(:subject) { build(:category_transaction, :random) }

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
end
