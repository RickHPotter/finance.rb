# frozen_string_literal: true

# == Schema Information
#
# Table name: categories
#
#  id            :bigint           not null, primary key
#  active        :boolean          default(TRUE), not null
#  built_in      :boolean          default(FALSE), not null
#  category_name :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  user_id       :bigint           not null
#
# Indexes
#
#  index_categories_on_user_id           (user_id)
#  index_category_name_on_composite_key  (user_id,category_name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
require "rails_helper"

RSpec.describe Category, type: :model do
  let!(:subject) { build(:category, :random, built_in: false) }

  describe "[ activerecord validations ]" do
    context "( presence, uniqueness, etc )" do
      it "is valid with valid attributes" do
        expect(subject).to be_valid
      end

      %i[category_name].each do |attribute|
        it { should validate_presence_of(attribute) }
      end

      it { should validate_uniqueness_of(:category_name).scoped_to(:user_id) }
    end

    context "( associations )" do
      bt_models = %i[user]
      hm_models = %i[category_transactions card_transactions cash_transactions investments]

      bt_models.each { |model| it { should belong_to(model) } }
      hm_models.each { |model| it { should have_many(model) } }
    end
  end

  describe "[ business logic ]" do
    context "( public methods )" do
      it "returns built_in value" do
        expect(subject.built_in?).to eq false
        subject.update(built_in: true)
        expect(subject.built_in?).to eq true
      end
    end
  end
end
