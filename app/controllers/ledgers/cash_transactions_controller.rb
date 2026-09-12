# frozen_string_literal: true

class Ledgers::CashTransactionsController < LedgersController
  def index
    state = ledger_query_state(:cash)
    result = ledger_query(state, include_rows: false)
    build_index_context(state, result)
    render Views::Ledgers::Index.new(context: ledger_index_context(kind: :cash, state:, result:, context: @index_context))
  end

  def search
    index
  end

  def month_year
    state = ledger_query_state(:cash)
    raise ActiveRecord::RecordNotFound if state.month_year.blank?

    result = ledger_query(state)
    render Views::Ledgers::Month.new(context: ledger_month_context(kind: :cash, state:, result:))
  end

  private

  def build_index_context(state, result) # rubocop:disable Metrics/AbcSize
    min_date, max_date = ledger_date_bounds(result, fallback: Time.zone.today)
    default_active_month_years = [ Time.zone.today.clamp(min_date, max_date).strftime("%Y%m").to_i ]
    years = (min_date.year..max_date.year)
    category_id = external_cash_category_ids
    entity_id = [ lala.id ]
    active_month_years = state.active_month_years.presence || default_active_month_years
    default_year = state.default_year || active_month_years.max.to_s.first(4).to_i

    @index_context = {
      current_user: user,
      external_route_params:,
      internal_route_params:,
      years:,
      default_year:,
      active_month_years:,
      search_term: state.search_term,
      category_id:,
      entity_id:,
      user_bank_account_id: [ result.user_bank_account&.id ].compact,
      user_card: @user_card,
      paid: state.paid,
      pending: state.pending,
      skip_budgets: state.skip_budgets,
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

  def external_cash_category_ids
    user.categories.where(category_name: [ "EXCHANGE RETURN", "BORROW RETURN" ]).ids
  end
end
