# frozen_string_literal: true

module Ledgers::InternalAccess
  extend ActiveSupport::Concern

  private

  def resolve_ledger_access!
    @ledger_access = Ledgers::Access::Internal.call(
      user: current_user,
      entity_public_id: params[:entity_public_id],
      context: current_context
    )
    raise ActiveRecord::RecordNotFound if @ledger_access.blank?
  end
end
