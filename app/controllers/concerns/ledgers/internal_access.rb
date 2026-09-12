# frozen_string_literal: true

module Ledgers::InternalAccess
  extend ActiveSupport::Concern

  included do
    before_action :redirect_legacy_internal_identity!
  end

  private

  def resolve_ledger_access!
    @ledger_access = Ledgers::Access::Internal.call(
      user: current_user,
      entity_public_id: params[:entity_public_id],
      context: current_context
    )
    if @ledger_access.blank?
      @ledger_access = Ledgers::Access::LegacyInternal.call(
        user: current_user,
        entity_slug: params[:entity_public_id],
        context: current_context
      )
      @legacy_internal_ledger_identity = @ledger_access.present?
    end
    raise ActiveRecord::RecordNotFound if @ledger_access.blank?
  end

  def redirect_legacy_internal_identity!
    return unless @legacy_internal_ledger_identity

    kind = current_ledger_kind
    state = ledger_query_state(kind)
    destination = if action_name == "month_year"
                    ledger_month_path(kind, **ledger_canonical_params(state))
                  else
                    ledger_index_path(kind, **ledger_index_canonical_params(state))
                  end
    redirect_to destination, status: :moved_permanently
  end
end
