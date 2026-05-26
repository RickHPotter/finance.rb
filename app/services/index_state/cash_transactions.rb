# frozen_string_literal: true

module IndexState
  class CashTransactions < Base
    extend CashPaidState

    DEFAULT_SORT = "default"
    DEFAULT_DIRECTION = "asc"
    VALID_SORTS = %w[default description installment_date transaction_date price].freeze
    VALID_DIRECTIONS = %w[asc desc].freeze
    TRANSACTION_FILTER_KEYS = %i[category_id entity_id cash_installment_ids user_bank_account_id].freeze
    RANGE_FILTER_KEYS = %i[
      from_ct_price
      to_ct_price
      from_price
      to_price
      from_installments_count
      to_installments_count
      from_installments_number
      to_installments_number
      from_date
      to_date
      exchange_bound_type
    ].freeze
    SEARCH_FILTER_KEYS = [
      :search_term,
      *RANGE_FILTER_KEYS,
      :paid,
      :pending,
      :paid_state,
      :exchange_bound_type,
      :skip_budgets,
      :force_mobile,
      :sort,
      :direction
    ].freeze

    def self.resolve_sort(sort:, direction:)
      resolved_sort = sort.presence_in(VALID_SORTS) || DEFAULT_SORT
      resolved_direction = direction.presence_in(VALID_DIRECTIONS) || DEFAULT_DIRECTION

      [ resolved_sort, resolved_direction ]
    end

    attr_reader :cash_installments, :transaction_filters, :search_filters, :selection_context, :years_override, :default_year_override, :active_month_years_override

    def initialize(current_user:, current_context:, params:, **options)
      super(current_user:, current_context:, params:)
      @cash_installments = options[:cash_installments]
      @transaction_filters = options[:transaction_filters] || {}
      @search_filters = options[:search_filters] || {}
      @selection_context = options[:selection_context]&.with_indifferent_access
      @years_override = options[:years]
      @default_year_override = options[:default_year]
      @active_month_years_override = options[:active_month_years]
    end

    def to_h
      state = resolved_state

      base_context(state).merge(
        filter_context,
        sort_context(state),
        results_context
      )
    end

    private

    def sort_context(state)
      {
        sort: state[:sort],
        direction: state[:direction]
      }
    end

    def results_context
      {
        count_by_month_year: count_by_month_year_for,
        available_subscriptions: subscriptions
      }
    end

    def resolved_state
      today_zn = Time.zone.today.beginning_of_month
      sort, direction = self.class.resolve_sort(sort: source_context[:sort], direction: source_context[:direction])

      {
        today_zn:,
        years: years_override || year_range_for(today_zn),
        active_month_years: active_month_years_override || active_month_years_for(today_zn:),
        sort:,
        direction:
      }
    end

    def base_context(state)
      {
        current_user:,
        years: state[:years],
        default_year: default_year_override || default_year_for(active_month_years: state[:active_month_years], today_zn: state[:today_zn]),
        active_month_years: state[:active_month_years]
      }
    end

    def filter_context
      paid_filters = self.class.resolve_paid_filters(
        paid_state: source_context[:paid_state],
        paid: source_context[:paid],
        pending: source_context[:pending]
      )

      values_from(source_context, :search_term, *RANGE_FILTER_KEYS, :exchange_bound_type, :skip_budgets).merge(
        compact_filter_context,
        user_card: nil,
        **paid_filters,
        force_mobile: boolean(source_context[:force_mobile])
      )
    end

    def source_context
      @source_context ||= selection_context || request_context
    end

    def request_context
      transaction_filter_context.merge(search_filter_context).with_indifferent_access
    end

    def transaction_filter_context
      values_from(transaction_filters, *TRANSACTION_FILTER_KEYS).merge(active_month_years: params[:active_month_years], default_year: params[:default_year])
    end

    def search_filter_context
      values_from(search_filters, *SEARCH_FILTER_KEYS)
    end

    def year_range_for(today_zn)
      min_year = cash_installments.minimum("installments.year") || today_zn.year
      max_year = cash_installments.maximum("installments.year") || today_zn.year

      (min_year..max_year)
    end

    def active_month_years_for(today_zn:)
      return compact_array_to_integers(source_context[:active_month_years]) if selection_context.present?
      return months_for_all_month_years if params[:all_month_years]

      parse_active_month_years(params[:active_month_years]).presence || default_active_month_years_for(today_zn:)
    end

    def default_active_month_years_for(today_zn:)
      default_active_month_years =
        cash_installments.where(paid: false, year: ..today_zn.year, month: ..today_zn.month)
                         .group(:year, :month)
                         .pluck(:year, :month)
                         .map { |year, month| month_year_value(year, month) }

      default_active_month_years = [ today_zn.strftime("%Y%m").to_i ] if default_active_month_years.empty?
      default_active_month_years
    end

    def months_for_all_month_years
      relation = relation_for_all_month_years
      relation.map { |installment| month_year_value(installment.year, installment.month) }.uniq
    end

    def relation_for_all_month_years
      associations = association_filters
      relation = cash_installments
      return relation.joins(cash_transaction: associations.keys).where(cash_transaction: associations.merge(account_filter)) if associations.present?
      return relation.joins(:cash_transaction).where(cash_transaction: account_filter) if account_filter.present?

      relation
    end

    def association_filters
      {}.tap do |associations|
        category_ids = compact_array(source_context[:category_id])
        entity_ids = compact_array(source_context[:entity_id])
        associations[:categories] = { id: category_ids } if category_ids.present?
        associations[:entities] = { id: entity_ids } if entity_ids.present?
      end
    end

    def account_filter
      { user_bank_account_id: compact_array(source_context[:user_bank_account_id]) }.compact_blank
    end

    def default_year_for(active_month_years:, today_zn:)
      explicit_default = source_context[:default_year].presence || params[:default_year]
      return explicit_default.to_i if explicit_default.present?
      return active_month_years.max.to_s.first(4).to_i if active_month_years.any?

      today_zn.year
    end

    def count_by_month_year_for
      if params[:action].in?(%w[create update]) && selection_context.blank?
        Logic::CashTransactions.find_count_based_on_search(current_context, {}, {})
      else
        Logic::CashTransactions.find_count_based_on_search(current_context, transaction_filters_for_count, search_filters_for_count)
      end
    end

    def compact_filter_context
      {
        category_id: compact_array(source_context[:category_id]),
        entity_id: compact_array(source_context[:entity_id]),
        cash_installment_ids: compact_array(source_context[:cash_installment_ids]),
        user_bank_account_id: compact_array(source_context[:user_bank_account_id])
      }
    end

    def transaction_filters_for_count
      compact_filter_context
    end

    def search_filters_for_count
      paid_filters = self.class.resolve_paid_filters(
        paid_state: source_context[:paid_state],
        paid: source_context[:paid],
        pending: source_context[:pending]
      )

      values_from(source_context, :search_term, *RANGE_FILTER_KEYS, :exchange_bound_type, :skip_budgets, :force_mobile).merge(
        **paid_filters,
        sort: self.class.resolve_sort(sort: source_context[:sort], direction: source_context[:direction]).first,
        direction: self.class.resolve_sort(sort: source_context[:sort], direction: source_context[:direction]).last
      )
    end
  end
end
