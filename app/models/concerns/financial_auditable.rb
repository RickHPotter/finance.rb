# frozen_string_literal: true

module FinancialAuditable
  extend ActiveSupport::Concern

  BASE_SKIPPED_ATTRIBUTES = %i[created_at updated_at].freeze

  class_methods do
    def audits_financial_changes(skip: [])
      has_paper_trail(
        skip: (BASE_SKIPPED_ATTRIBUTES + skip).uniq,
        meta: {
          operation_id: ->(_) { Audit::Operation.ensure_persisted!.id },
          owner_id: ->(record) { Audit::OwnershipResolver.resolve!(record).owner_id },
          context_id: ->(record) { Audit::OwnershipResolver.resolve!(record).context_id },
          mutation_source: ->(_) { Audit::Current.mutation_source.presence || "unknown" },
          metadata: ->(record) { Audit::VersionMetadata.for(record) }
        }
      )
    end
  end
end
