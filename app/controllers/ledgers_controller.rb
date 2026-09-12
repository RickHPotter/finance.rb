# frozen_string_literal: true

class LedgersController < ApplicationController
  include TranslateHelper

  before_action :resolve_ledger_access!
  before_action :set_user_agent
  before_action :set_tabs, unless: :external_ledger?

  private

  attr_reader :ledger_access

  def resolve_ledger_access!
    raise NotImplementedError
  end

  def user
    ledger_access.user
  end

  def ledger_entity
    ledger_access.entity
  end

  def ledger_context
    ledger_access.context
  end

  def set_user_agent
    @mobile = true if request.user_agent =~ /Mobile|Android|iPhone|iPad/
  end

  def set_tabs(active_menu: :cash, active_sub_menu: :pix)
    @active_menu = active_menu
    @active_sub_menu = active_sub_menu
    set_variables
  end

  def exchange_category
    user.categories.find_by(category_name: "EXCHANGE")
  end

  def user_cards
    return user.user_cards if exchange_category.nil?

    user.user_cards
        .joins(card_transactions: %i[category_transactions entity_transactions])
        .where(card_transactions: { context_id: ledger_context.id })
        .where(category_transactions: { category_id: exchange_category.id })
        .where(entity_transactions: { entity_id: ledger_entity.id })
        .group("user_cards.id")
        .order(active: :desc)
  end

  def set_variables
    tab_params = ledger_tab_params(ledger_query_state(current_ledger_kind))
    @main_items = [ { label: t("tabs.pix"), icon: :mobile, link: ledger_cash_transactions_path(**tab_params), default: @active_menu == :pix } ]
    @main_items += user_cards.pluck(:id, :user_card_name).map do |user_card_id, user_card_name|
      default = @active_sub_menu.to_sym == user_card_name.to_sym
      { label: user_card_name, icon: :credit_card, link: ledger_card_transactions_path(**tab_params, user_card_id:), default: }
    end

    @main_items.first[:default] = true if @main_items.pluck(:default).uniq == [ false ]
    @main_items.map! { |item| item.slice(:label, :icon, :link, :default).values }
    @main_tab = @main_items.map { |label, icon, link, default| Item.new(label, icon, link, default, 0) }
    @main_tab.each { |tab| tab.label = tab.label.split.first } if @mobile
  end

  def external_route_params
    return unless ledger_access.share

    { share_token: params[:share_token] }
  end

  def internal_route_params
    return if ledger_access.share

    { entity_public_id: ledger_entity.public_id }
  end

  def ledger_cash_transactions_path(**query_params)
    return external_cash_transactions_path(**external_route_params, **query_params) if ledger_access.share

    internal_cash_transactions_path(**internal_route_params, **query_params)
  end

  def ledger_card_transactions_path(**query_params)
    return external_card_transactions_path(**external_route_params, **query_params) if ledger_access.share

    internal_card_transactions_path(**internal_route_params, **query_params)
  end

  def ledger_query_state(kind)
    @ledger_query_states ||= {}
    @ledger_query_states[kind] ||= Ledgers::QueryState.new(kind:, params:)
  end

  def ledger_query(state, include_rows: true)
    Ledgers::Query.call(access: ledger_access, state:, include_rows:)
  end

  def ledger_index_context(kind:, state:, result:, context:)
    context = context.merge(
      kind:,
      external: external_ledger?,
      header: Ledgers::Presenters::Header.new(access: ledger_access, result:),
      index_path: ledger_index_path(kind),
      month_path: ledger_month_path(kind),
      cash_path: ledger_cash_transactions_path(**ledger_tab_params(state)),
      card_path: ledger_card_transactions_path(**ledger_tab_params(state)),
      canonical_params: ledger_index_canonical_params(state)
    )
    context.merge!(current_user: nil, user_card: nil, user_card_id: nil, user_bank_account_id: nil) if external_ledger?
    context
  end

  def ledger_month_context(kind:, state:, result:)
    {
      kind:,
      external: external_ledger?,
      month_year: state.month_year,
      rows: ledger_rows(result.rows, kind:),
      total_count: result.total_count,
      total_amount: result.total_amount,
      page: result.page,
      per_page: result.per_page,
      index_path: ledger_index_path(kind),
      month_path: ledger_month_path(kind),
      canonical_params: ledger_index_canonical_params(state)
    }
  end

  def ledger_rows(installments, kind:)
    if external_ledger?
      installments.map { |installment| Ledgers::Presenters::ExternalRow.build(installment:, kind:, share: ledger_access.share) }
    else
      display_mode = CategoryColours::DisplayMode.for(user)
      installments.map { |installment| Ledgers::Presenters::InternalRow.new(installment:, kind:, category_colour_display_mode: display_mode) }
    end
  end

  def ledger_index_path(kind, **query_params)
    kind == :cash ? ledger_cash_transactions_path(**query_params) : ledger_card_transactions_path(**query_params)
  end

  def ledger_month_path(kind, **query_params)
    route_params = external_ledger? ? external_route_params : internal_route_params
    return month_year_external_cash_transactions_path(**route_params, **query_params) if external_ledger? && kind == :cash
    return month_year_external_card_transactions_path(**route_params, **query_params) if external_ledger?
    return month_year_internal_cash_transactions_path(**route_params, **query_params) if kind == :cash

    month_year_internal_card_transactions_path(**route_params, **query_params)
  end

  def external_ledger?
    ledger_access.share.present?
  end

  def ledger_canonical_params(state)
    params = state.canonical_params
    external_ledger? ? params.except(:cash_transaction, :card_transaction) : params
  end

  def ledger_index_canonical_params(state)
    ledger_canonical_params(state).except(:month_year)
  end

  def ledger_tab_params(state)
    params = ledger_index_canonical_params(state).slice(:active_month_years, :default_year, :search_term, :direction, :per_page, :force_mobile)
    params[:sort] = state.sort if state.sort.in?(%w[description installment_date transaction_date price])
    params
  end

  def current_ledger_kind
    controller_name == "card_transactions" ? :card : :cash
  end

  def redirect_canonical_ledger_entry?(state, kind:)
    return false unless params[:ledger_entry]

    redirect_to ledger_index_path(kind, **ledger_index_canonical_params(state)), status: :moved_permanently
    true
  end
end
