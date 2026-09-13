# frozen_string_literal: true

module Ledgers::PublicAliasAccess
  extend ActiveSupport::Concern
  include Ledgers::ExternalSecurity

  included do
    skip_before_action :authenticate_user!
    layout "ledger_external"
    rescue_from ActiveRecord::RecordNotFound, with: :public_ledger_unavailable
  end

  private

  def resolve_ledger_access!
    @ledger_access = Ledgers::Access::PublicAlias.call(alias_name: :lalas)
    raise ActiveRecord::RecordNotFound if @ledger_access.blank?
  end

  def external_rate_limit_identity
    "public-alias:lalas"
  end

  def ledger_cash_transactions_path(**query_params)
    lalas_cash_transactions_path(**query_params)
  end

  def ledger_card_transactions_path(**query_params)
    lalas_card_transactions_path(**query_params)
  end

  def ledger_month_path(kind, **query_params)
    return month_year_lalas_cash_transactions_path(**query_params) if kind == :cash

    month_year_lalas_card_transactions_path(**query_params)
  end

  def public_ledger_unavailable
    render Views::Ledgers::Unavailable.new, status: :not_found
  end
end
