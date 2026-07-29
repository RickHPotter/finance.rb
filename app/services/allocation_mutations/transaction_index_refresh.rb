# frozen_string_literal: true

class AllocationMutations::TransactionIndexRefresh
  class UnsupportedOwner < ArgumentError; end

  attr_reader :actor, :context, :owner_type, :destination, :mobile

  def initialize(actor:, context:, owner_type:, destination:, mobile: false)
    @actor = actor
    @context = context
    @owner_type = owner_type.to_s
    @destination = destination
    @mobile = mobile
  end

  def view
    case owner_type
    when "CashTransaction" then cash_view
    when "CardTransaction" then card_view
    else raise UnsupportedOwner, "unsupported transaction index owner: #{owner_type}"
    end
  end

  private

  def cash_view
    index_context = IndexState::CashTransactions.new(
      current_user: actor,
      current_context: context,
      params: request_params,
      cash_installments: context.cash_installments,
      transaction_filters: nested_filters(:cash_transaction),
      search_filters: query
    ).to_h
    index_context[:return_to] = destination unless destination == cash_transactions_path

    Views::CashTransactions::Index.new(index_context:, mobile: resolved_mobile(index_context))
  end

  def card_view
    user_card = actor.user_cards.find_by(id: selected_user_card_id)
    installments = context.card_installments
    installments = installments.joins(:card_transaction).where(card_transactions: { user_card_id: user_card.id }) if user_card
    index_context = IndexState::CardTransactions.new(
      current_user: actor,
      current_context: context,
      params: request_params,
      card_installments: installments,
      user_card:,
      transaction_filters: nested_filters(:card_transaction),
      search_filters: query
    ).to_h
    index_context[:return_to] = destination unless destination == card_transactions_path

    Views::CardTransactions::Index.new(
      index_context:,
      search: destination_uri.path == search_card_transactions_path,
      mobile: resolved_mobile(index_context)
    )
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

  def selected_user_card_id
    value = query[:user_card_id].presence || nested_filters(:card_transaction)[:user_card_id]
    Array(value).compact_blank.first
  end

  def resolved_mobile(index_context)
    mobile || index_context[:force_mobile]
  end

  def destination_uri
    @destination_uri ||= URI.parse(destination)
  end

  def cash_transactions_path
    Rails.application.routes.url_helpers.cash_transactions_path
  end

  def card_transactions_path
    Rails.application.routes.url_helpers.card_transactions_path
  end

  def search_card_transactions_path
    Rails.application.routes.url_helpers.search_card_transactions_path
  end
end
