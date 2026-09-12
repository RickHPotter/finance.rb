# frozen_string_literal: true

module Ledgers::ExternalAccess
  extend ActiveSupport::Concern

  included do
    skip_before_action :authenticate_user!
    layout "ledger_external"
    rescue_from ActiveRecord::RecordNotFound, with: :ledger_share_unavailable
  end

  private

  def resolve_ledger_access!
    @ledger_access = Ledgers::Access::External.call(token: params[:share_token])
    raise ActiveRecord::RecordNotFound if @ledger_access.blank?
  end

  def ledger_share_unavailable
    render Views::Ledgers::Unavailable.new, status: :not_found
  end
end
