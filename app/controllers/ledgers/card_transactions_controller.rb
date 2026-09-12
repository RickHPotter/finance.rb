# frozen_string_literal: true

class Ledgers::CardTransactionsController < LedgersController
  def index
    state = ledger_query_state(:card)
    return if redirect_canonical_ledger_entry?(state, kind: :card)

    result = ledger_query(state, include_rows: false)
    @user_card = result.user_card
    build_index_context(state, result)
    set_tabs(active_menu: :card, active_sub_menu: @user_card&.user_card_name || :search) unless external_ledger?
    render Views::Ledgers::Index.new(context: ledger_index_context(kind: :card, state:, result:, context: @index_context))
  end

  def search
    state = ledger_query_state(:card)
    redirect_to ledger_index_path(:card, **ledger_index_canonical_params(state)), status: :moved_permanently
  end

  def month_year
    state = ledger_query_state(:card)
    raise ActiveRecord::RecordNotFound if state.month_year.blank?

    result = ledger_query(state)
    render Views::Ledgers::Month.new(context: ledger_month_context(kind: :card, state:, result:))
  end

  private

  def build_index_context(state, result) # rubocop:disable Metrics/AbcSize
    min_date, max_date = ledger_date_bounds(result, fallback: Time.zone.today + 1.month)
    default_active_month_years = [ [ max_date, Time.zone.today + 1.month ].min.strftime("%Y%m").to_i ]
    years = (min_date.year..max_date.year)
    category_id = external_card_category_ids
    entity_id = [ ledger_entity.id ]
    active_month_years = state.active_month_years_provided ? state.active_month_years : default_active_month_years
    default_year = state.default_year || (active_month_years.max / 100 if active_month_years.any?) || [ max_date, Time.zone.today + 1.month ].min.year

    @index_context = {
      current_user: user,
      external_route_params:,
      internal_route_params:,
      years:,
      default_year:,
      active_month_years:,
      search_term: state.search_term,
      card_installment_ids: [],
      category_id:,
      entity_id:,
      from_ct_price: nil,
      to_ct_price: nil,
      from_price: nil,
      to_price: nil,
      from_installments_count: nil,
      to_installments_count: nil,
      user_card: @user_card,
      force_mobile: state.force_mobile,
      sort: state.sort,
      direction: state.direction,
      page: state.page,
      per_page: state.per_page,
      count_by_month_year: result.count_by_month_year
    }
  end

  def ledger_date_bounds(result, fallback:)
    return [ fallback, fallback ] if result.months.empty?

    [ result.months.first.month_year, result.months.last.month_year ].map do |month_year|
      Date.new(month_year / 100, month_year % 100, 1)
    end
  end

  def external_card_category_ids
    user.categories.where(category_name: [ "EXCHANGE" ]).ids
  end
end
