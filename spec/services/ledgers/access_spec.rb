# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledgers::Access, type: :service do
  it "resolves internal access only for an Entity and Context belonging to the user" do
    user = create(:user, :random)
    entity = create(:entity, user:)
    foreign_user = create(:user, :random)

    access = Ledgers::Access::Internal.call(user:, entity_public_id: entity.public_id, context: user.main_context)

    expect(access).to have_attributes(user:, entity:, context: user.main_context, share: nil)
    expect(Ledgers::Access::Internal.call(user: foreign_user, entity_public_id: entity.public_id, context: foreign_user.main_context)).to be_nil
    expect(Ledgers::Access::Internal.call(user:, entity_public_id: entity.public_id, context: foreign_user.main_context)).to be_nil
  end

  it "derives external owner, Entity, and Context exclusively from the active share" do
    entity = create(:entity, :random)
    share = Ledgers::Shares::Create.call(entity:, context: entity.user.main_context)

    access = Ledgers::Access::External.call(token: share.token)

    expect(access).to have_attributes(user: entity.user, entity:, context: entity.user.main_context, share: share.share)
    expect(Ledgers::Access::External.call(token: "unknown")).to be_nil
  end
end
