# frozen_string_literal: true

# == Schema Information
#
# Table name: entities
#
#  id          :bigint           not null, primary key
#  active      :boolean          default(TRUE), not null
#  entity_name :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  user_id     :bigint           not null
#
# Indexes
#
#  index_entities_on_entity_name       (entity_name) UNIQUE
#  index_entities_on_user_id           (user_id)
#  index_entity_name_on_composite_key  (user_id,entity_name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
require "rails_helper"

RSpec.describe Entity, type: :model do
  let!(:subject) { build(:entity, :random) }

  describe "[ activerecord validations ]" do
    context "( presence, uniqueness, etc )" do
      it "is valid with valid attributes" do
        expect(subject).to be_valid
      end

      %i[entity_name].each do |attribute|
        it { should validate_presence_of(attribute) }
      end

      it { should validate_uniqueness_of(:entity_name).scoped_to(:user_id) }
    end

    context "( associations )" do
      bt_models = %i[user]
      hm_models = %i[entity_transactions card_transactions cash_transactions]

      bt_models.each { |model| it { should belong_to(model) } }
      hm_models.each { |model| it { should have_many(model) } }
    end
  end
end
