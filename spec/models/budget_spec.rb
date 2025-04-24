# frozen_string_literal: true

require "rails_helper"

RSpec.describe Budget, type: :model do
  let(:subject) { build(:budget) }

  describe "[ activerecord validations ]" do
    context "( presence, uniqueness, etc )" do
      it "is valid with valid attributes" do
        expect(subject).to be_valid
      end

      %i[month year].each do |attribute|
        it { should validate_presence_of(attribute) }
      end
    end

    context "( associations )" do
      it { should belong_to(:user) }

      hm_models = %i[budget_categories categories budget_entities entities]
      hm_models.each { |model| it { should have_many(model) } }
    end
  end
end

# == Schema Information
#
# Table name: budgets
#
#  id              :bigint           not null, primary key
#  active          :boolean          default(TRUE), not null
#  balance         :integer
#  description     :string           not null
#  inclusive       :boolean          default(TRUE), not null
#  month           :integer          not null
#  remaining_value :integer          not null
#  starting_value  :integer          not null
#  value           :integer          not null
#  year            :integer          not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  order_id        :integer          not null
#  user_id         :bigint           not null, indexed
#
# Indexes
#
#  index_budgets_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
