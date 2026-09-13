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

  it "resolves an unambiguous legacy slug from current database state" do
    user = create(:user, :random)
    user.entities.load
    entity = create(:entity, user:, entity_name: "CRÍSTIAN PENS")

    access = Ledgers::Access::LegacyInternal.call(user:, entity_slug: "cristian-pens", context: user.main_context)

    expect(access).to have_attributes(user:, entity:, context: user.main_context, share: nil)

    create(:entity, user:, entity_name: "CRISTIAN PENS")
    expect(Ledgers::Access::LegacyInternal.call(user:, entity_slug: "cristian-pens", context: user.main_context)).to be_nil
  end

  it "resolves the public lalas alias only when its active Entity is unambiguous" do
    entity = create(:entity, :random, entity_name: "LALA")

    access = Ledgers::Access::PublicAlias.call(alias_name: :lalas)

    expect(access).to have_attributes(user: entity.user, entity:, context: entity.user.main_context)
    expect(access.share.public_id).to include("public-alias:lalas:", entity.public_id)

    create(:entity, :random, entity_name: "lala")
    expect(Ledgers::Access::PublicAlias.call(alias_name: :lalas)).to be_nil
  end

  it "supports an explicit stable Entity public ID for the lalas alias" do
    named_entity = create(:entity, :random, entity_name: "LALA")
    configured_entity = create(:entity, :random, entity_name: "SISTER")

    access = Ledgers::Access::PublicAlias.call(alias_name: :lalas, entity_public_id: configured_entity.public_id)

    expect(access.entity).to eq(configured_entity)
    expect(access.entity).not_to eq(named_entity)
  end
end
