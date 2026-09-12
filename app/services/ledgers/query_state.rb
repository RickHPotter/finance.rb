# frozen_string_literal: true

class Ledgers::QueryState
  KINDS = %i[cash card].freeze
  MIN_YEAR = 1900
  MAX_YEAR = 3000
  DEFAULT_PER_PAGE = 100
  MAX_PER_PAGE = 250

  attr_reader :kind, :month_year, :active_month_years, :default_year, :search_term,
              :paid, :pending, :sort, :direction, :page, :per_page,
              :user_bank_account_id, :user_card_id, :force_mobile, :skip_budgets,
              :active_month_years_provided

  def initialize(kind:, params:) # rubocop:disable Metrics/AbcSize
    @kind = kind.to_sym
    raise ArgumentError, "Unsupported ledger kind: #{kind}" unless kind.in?(KINDS)

    source = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
    source = source.with_indifferent_access
    transaction = source.fetch("#{@kind}_transaction", {}).to_h.with_indifferent_access
    @month_year = valid_month_year(source[:month_year])
    @active_month_years_provided = source.key?(:active_month_years)
    @active_month_years = parse_month_years(source[:active_month_years])
    @default_year = bounded_integer(source[:default_year], MIN_YEAR..MAX_YEAR)
    @search_term = source[:search_term].to_s.squish.first(200)
    @paid, @pending = resolve_paid_state(source)
    @sort, @direction = resolve_sort(source)
    @page = bounded_integer(source[:page], 1..) || 1
    @per_page = bounded_integer(source[:per_page], 1..MAX_PER_PAGE) || DEFAULT_PER_PAGE
    @user_bank_account_id = positive_integer(transaction[:user_bank_account_id] || source[:user_bank_account_id])
    @user_card_id = positive_integer(transaction[:user_card_id] || source[:user_card_id])
    @force_mobile = boolean(source[:force_mobile])
    @skip_budgets = boolean(source[:skip_budgets])
  end

  def canonical_params
    {
      month_year:,
      active_month_years: (active_month_years.to_json if active_month_years_provided?),
      default_year:,
      search_term: search_term.presence,
      paid: (paid if kind == :cash),
      pending: (pending if kind == :cash),
      sort:,
      direction:,
      page: (page if page > 1),
      per_page: (per_page if per_page != DEFAULT_PER_PAGE),
      force_mobile: (true if force_mobile),
      skip_budgets: (true if skip_budgets),
      "#{kind}_transaction": transaction_params.presence
    }.compact
  end

  private

  def active_month_years_provided?
    active_month_years_provided
  end

  def transaction_params
    return { user_bank_account_id: } if kind == :cash && user_bank_account_id
    return { user_card_id: } if kind == :card && user_card_id

    {}
  end

  def resolve_paid_state(source)
    return [ true, true ] unless kind == :cash

    filters = IndexState::CashTransactions.resolve_paid_filters(
      paid_state: source[:paid_state],
      paid: source[:paid],
      pending: source[:pending]
    )
    [ filters[:paid], filters[:pending] ]
  end

  def resolve_sort(source)
    if kind == :cash
      IndexState::CashTransactions.resolve_sort(sort: source[:sort], direction: source[:direction])
    else
      IndexState::CardTransactions.resolve_sort(sort: source[:sort], direction: source[:direction], order_by: source[:order_by])
    end
  end

  def parse_month_years(value)
    values = value.is_a?(String) ? JSON.parse(value) : value
    Array(values).filter_map { |candidate| valid_month_year(candidate) }.uniq.sort
  rescue JSON::ParserError, TypeError
    []
  end

  def valid_month_year(value)
    raw = value.to_s
    return unless raw.match?(/\A\d{6}\z/)

    year = raw.first(4).to_i
    month = raw.last(2).to_i
    raw.to_i if year.in?(MIN_YEAR..MAX_YEAR) && month.in?(1..12)
  end

  def positive_integer(value)
    integer = Integer(Array(value).compact_blank.first, exception: false)
    integer if integer&.positive?
  end

  def bounded_integer(value, range)
    integer = Integer(value, exception: false)
    integer if integer&.in?(range)
  end

  def boolean(value)
    ActiveModel::Type::Boolean.new.cast(value)
  end
end
