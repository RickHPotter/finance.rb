# frozen_string_literal: true

require "rails_helper"

RSpec.describe LedgerShare, type: :model do
  it "accepts an Entity and Context owned by the same user" do
    entity = create(:entity, :random)

    expect(build(:ledger_share, entity:, context: entity.user.main_context)).to be_valid
  end

  it "rejects a Context owned by another user" do
    entity = create(:entity, :random)
    foreign_context = create(:user, :random).main_context
    share = build(:ledger_share, entity:, context: foreign_context)

    expect(share).not_to be_valid
    expect(share.errors[:context]).to include(I18n.t("activerecord.errors.models.ledger_share.attributes.context.owner_mismatch"))
  end

  it "enforces Entity and Context ownership in PostgreSQL" do
    entity = create(:entity, :random)
    foreign_context = create(:user, :random).main_context

    expect do
      LedgerShare.insert_all!([
                                {
                                  entity_id: entity.id,
                                  context_id: foreign_context.id,
                                  public_id: SecureRandom.uuid,
                                  token_digest: LedgerShare.digest_token("foreign-owner"),
                                  created_at: Time.current,
                                  updated_at: Time.current
                                }
                              ])
    end.to raise_error(ActiveRecord::StatementInvalid)
  end

  it "requires a future expiry when an expiry is provided" do
    share = build(:ledger_share, expires_at: 1.minute.ago)

    expect(share).not_to be_valid
    expect(share.errors[:expires_at]).to include(I18n.t("activerecord.errors.models.ledger_share.attributes.expires_at.must_be_future"))
  end

  it "keeps identity, token digest, Entity, and Context immutable" do
    share = create(:ledger_share)
    other_entity = create(:entity, user: share.entity.user, entity_name: "OTHER LEDGER ENTITY")
    other_context = create(:context, user: share.entity.user, source_context: share.context, name: "Other Ledger Context")
    replacements = {
      public_id: SecureRandom.uuid,
      token_digest: LedgerShare.digest_token("replacement"),
      entity_id: other_entity.id,
      context_id: other_context.id
    }

    replacements.each do |attribute, replacement|
      expect { share.update!(attribute => replacement) }.to raise_error(ActiveRecord::ReadonlyAttributeError)
    end
  end
end

# == Schema Information
#
# Table name: ledger_shares
# Database name: primary
#
#  id               :bigint           not null, primary key
#  access_count     :bigint           default(0), not null
#  expires_at       :datetime
#  last_accessed_at :datetime
#  revoked_at       :datetime
#  token_digest     :string           not null, uniquely indexed
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  context_id       :bigint           not null, indexed => [entity_id], indexed
#  entity_id        :bigint           not null, indexed => [context_id], indexed
#  public_id        :uuid             not null, uniquely indexed
#
# Indexes
#
#  index_active_ledger_shares_on_scope  (entity_id,context_id) WHERE (revoked_at IS NULL)
#  index_ledger_shares_on_context_id    (context_id)
#  index_ledger_shares_on_entity_id     (entity_id)
#  index_ledger_shares_on_public_id     (public_id) UNIQUE
#  index_ledger_shares_on_token_digest  (token_digest) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (context_id => contexts.id)
#  fk_rails_...  (entity_id => entities.id)
#
