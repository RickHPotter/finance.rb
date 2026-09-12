# frozen_string_literal: true

class Ledgers::ExternalCompatibilityController < ApplicationController
  skip_before_action :authenticate_user!
  layout "ledger_external"
  rescue_from ActiveRecord::RecordNotFound, with: :ledger_unavailable

  def show
    access = Ledgers::Access::External.call(token: params[:share_token])
    raise ActiveRecord::RecordNotFound if access.blank?

    state = Ledgers::QueryState.new(kind: params[:ledger_kind], params:)
    redirect_to canonical_path(state), status: :moved_permanently
  end

  private

  def canonical_path(state)
    route_params = { share_token: params[:share_token] }
    query = state.canonical_params.except(:cash_transaction, :card_transaction)

    if params[:ledger_endpoint] == "month_year"
      return month_year_external_cash_transactions_path(**route_params, **query) if state.kind == :cash

      return month_year_external_card_transactions_path(**route_params, **query)
    end

    query = query.except(:month_year)
    return external_cash_transactions_path(**route_params, **query) if state.kind == :cash

    external_card_transactions_path(**route_params, **query)
  end

  def ledger_unavailable
    render Views::Ledgers::Unavailable.new, status: :not_found
  end
end
