# frozen_string_literal: true

require "rails_helper"

RSpec.describe Entity, type: :model do
  let(:subject) { build(:entity, :random) }

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

  describe "[ business logic ]" do
    it "defaults built_in to false" do
      expect(build(:entity, built_in: nil).built_in?).to be(false)
    end

    it "allows renaming a built-in entity" do
      entity = create(:user).built_in_entity

      expect(entity.update(entity_name: "NOUS")).to be(true)
      expect(entity.reload.entity_name).to eq("NOUS")
    end

    it "does not allow deactivating a built-in entity" do
      entity = create(:user).built_in_entity

      expect(entity.update(active: false)).to be(false)
      expect(entity.errors[:active]).to include(I18n.t("activerecord.errors.models.entity.attributes.active.cannot_deactivate_built_in"))
      expect(entity.reload.active).to be(true)
    end

    it "does not allow destroying a built-in entity" do
      entity = create(:user).built_in_entity

      expect(entity.destroy).to be(false)
      expect(entity.errors[:base]).to include(I18n.t("activerecord.errors.models.entity.attributes.base.cannot_destroy_built_in"))
      expect(entity.reload).to be_present
    end
  end
end

# == Schema Information
#
# Table name: entities
# Database name: primary
#
#  id                      :bigint           not null, primary key
#  active                  :boolean          default(TRUE), not null
#  avatar_name             :string           default("people/0.png"), not null
#  built_in                :boolean          default(FALSE), not null
#  card_transactions_count :integer          default(0), not null
#  card_transactions_total :integer          default(0), not null
#  cash_transactions_count :integer          default(0), not null
#  cash_transactions_total :integer          default(0), not null
#  entity_name             :string           not null, uniquely indexed => [user_id]
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  entity_user_id          :bigint           indexed
#  user_id                 :bigint           not null, indexed, uniquely indexed => [entity_name]
#
# Indexes
#
#  index_entities_on_entity_user_id    (entity_user_id)
#  index_entities_on_user_id           (user_id)
#  index_entity_name_on_composite_key  (user_id,entity_name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (entity_user_id => users.id)
#  fk_rails_...  (user_id => users.id)
#
