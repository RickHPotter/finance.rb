# frozen_string_literal: true

FactoryBot.define do
  factory :ledger_share do
    entity
    context { entity.user.main_context }
    sequence(:token_digest) { |number| LedgerShare.digest_token("ledger-share-token-#{number}") }
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
