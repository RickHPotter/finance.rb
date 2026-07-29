# frozen_string_literal: true

class AllocationMutations::BudgetIndexRefresh
  class UnsupportedDestination < ArgumentError; end

  attr_reader :actor, :context, :destination, :mobile

  def initialize(actor:, context:, destination:, mobile: false)
    @actor = actor
    @context = context
    @destination = destination
    @mobile = mobile
  end

  def view
    return budget_view if destination_uri.path == budgets_path
    return cash_view if destination_uri.path == cash_transactions_path

    raise UnsupportedDestination, "unsupported Budget index destination: #{destination_uri.path}"
  end

  private

  def budget_view
    index_context = IndexState::Budgets.new(
      current_user: actor,
      current_context: context,
      params: request_params,
      budget_filters: nested_filters(:budget),
      search_filters: query
    ).to_h
    index_context[:return_to] = destination unless destination == budgets_path

    Views::Budgets::Index.new(index_context:, mobile: resolved_mobile(index_context))
  end

  def cash_view
    AllocationMutations::TransactionIndexRefresh.new(
      actor:,
      context:,
      owner_type: "CashTransaction",
      destination:,
      mobile:
    ).view
  end

  def query
    @query ||= Rack::Utils.parse_nested_query(destination_uri.query.to_s).with_indifferent_access
  end

  def request_params
    @request_params ||= ActionController::Parameters.new(query.to_h)
  end

  def nested_filters(key)
    query[key].presence || {}
  end

  def resolved_mobile(index_context)
    mobile || index_context[:force_mobile]
  end

  def destination_uri
    @destination_uri ||= URI.parse(destination)
  end

  def budgets_path
    Rails.application.routes.url_helpers.budgets_path
  end

  def cash_transactions_path
    Rails.application.routes.url_helpers.cash_transactions_path
  end
end
