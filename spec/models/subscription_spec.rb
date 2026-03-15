# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscription, type: :model do
  let(:subject) { build(:subscription) }

  describe "[ activerecord validations ]" do
    context "( presence, enums, etc )" do
      it "is valid with valid attributes" do
        expect(subject).to be_valid
      end

      %i[user description status].each do |attribute|
        it { should validate_presence_of(attribute) }
      end

      it { should define_enum_for(:status).with_values(active: "active", paused: "paused", finished: "finished").backed_by_column_of_type(:string) }
      it { should validate_numericality_of(:price) }
    end

    context "( associations )" do
      it { should belong_to(:user) }
      it { should have_many(:category_transactions).dependent(:destroy) }
      it { should have_many(:entity_transactions).dependent(:destroy) }
    end
  end

  describe "[ business logic ]" do
    context "( defaults )" do
      it "defaults to active status on create" do
        subscription = described_class.create!(user: create(:user, :random), description: "Gym membership")

        expect(subscription).to be_active
      end
    end

    context "( lightweight intent model )" do
      it "allows zero price as a starting calculated value" do
        subject.price = 0

        expect(subject).to be_valid
      end
    end
  end
end

# == Schema Information
#
# Table name: finance_subscriptions
# Database name: primary
#
#  id          :bigint           not null, primary key
#  comment     :text
#  description :string           not null
#  price       :integer          default(0), not null
#  status      :string           default("active"), not null, indexed
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  user_id     :bigint           not null, indexed
#
# Indexes
#
#  index_finance_subscriptions_on_status   (status)
#  index_finance_subscriptions_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
