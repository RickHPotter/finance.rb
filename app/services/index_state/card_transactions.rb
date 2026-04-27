# frozen_string_literal: true

module IndexState
  class CardTransactions < Base
    DEFAULT_SORT = "installment_date"
    DEFAULT_DIRECTION = "asc"
    VALID_SORTS = %w[description installment_date transaction_date price].freeze
    VALID_DIRECTIONS = %w[asc desc].freeze
    TRANSACTION_FILTER_KEYS = %i[card_installment_ids category_id entity_id].freeze
    RANGE_FILTER_KEYS = %i[
      from_ct_price
      to_ct_price
      from_price
      to_price
      from_installments_count
      to_installments_count
      from_installments_number
      to_installments_number
    ].freeze
    SEARCH_FILTER_KEYS = [
      :search_term,
      *RANGE_FILTER_KEYS,
      :exchange_bound_type,
      :force_mobile,
      :sort,
      :direction,
      :order_by
    ].freeze
    LEGACY_ORDER_BY_TO_SORT = {
      "installment_date" => DEFAULT_SORT,
      "transaction_date" => "transaction_date"
    }.freeze
    SORT_TO_LEGACY_ORDER_BY = LEGACY_ORDER_BY_TO_SORT.invert.freeze

    attr_reader :card_installments, :user_card, :transaction_filters, :search_filters, :selection_context

    def self.resolve_sort(sort:, direction:, order_by:)
      resolved_sort = sort.presence_in(VALID_SORTS) || LEGACY_ORDER_BY_TO_SORT[order_by] || DEFAULT_SORT
      resolved_direction = direction.presence_in(VALID_DIRECTIONS) || DEFAULT_DIRECTION

      [ resolved_sort, resolved_direction ]
    end

    def self.legacy_order_by_for(sort) = SORT_TO_LEGACY_ORDER_BY[sort] || DEFAULT_SORT

    def initialize(current_user:, current_context:, params:, **options)
      super(current_user:, current_context:, params:)
      @card_installments = options[:card_installments]
      @user_card = options[:user_card]
      @transaction_filters = options[:transaction_filters] || {}
      @search_filters = options[:search_filters] || {}
      @selection_context = options[:selection_context]&.with_indifferent_access
    end

    def to_h
      state = resolved_state

      base_context(state).merge(
        filter_context,
        sort_context(state),
        results_context(state)
      )
    end

    private

    def results_context(state)
      {
        count_by_month_year: count_by_month_year_for(state),
        available_subscriptions: subscriptions
      }
    end

    def resolved_state
      today = Time.zone.today
      min_date, max_date = date_bounds(today)
      sort, direction = self.class.resolve_sort(
        sort: source_context[:sort],
        direction: source_context[:direction],
        order_by: source_context[:order_by]
      )

      {
        today:,
        min_date:,
        max_date:,
        active_month_years: active_month_years_for(max_date:, today:),
        sort:,
        direction:
      }
    end

    def base_context(state)
      {
        current_user:,
        years: (state[:min_date].year..state[:max_date].year),
        default_year: default_year_for(active_month_years: state[:active_month_years], max_date: state[:max_date], today: state[:today]),
        active_month_years: state[:active_month_years]
      }
    end

    def filter_context
      values_from(source_context, :search_term, *RANGE_FILTER_KEYS, :exchange_bound_type).merge(
        compact_filter_context,
        user_card_context,
        force_mobile: boolean(source_context[:force_mobile])
      )
    end

    def compact_filter_context
      {
        card_installment_ids: compact_array(source_context[:card_installment_ids]),
        category_id: compact_array(source_context[:category_id]),
        entity_id: compact_array(source_context[:entity_id])
      }
    end

    def user_card_context
      {
        user_card: resolved_user_card,
        user_card_id: resolved_user_card&.id
      }
    end

    def date_bounds(today)
      fallback = today + 1.month

      [
        card_installments.minimum("MAKE_DATE(installments.year, installments.month, 1)") || fallback,
        card_installments.maximum("MAKE_DATE(installments.year, installments.month, 1)") || fallback
      ]
    end

    def sort_context(state)
      {
        sort: state[:sort],
        direction: state[:direction],
        order_by: self.class.legacy_order_by_for(state[:sort])
      }
    end

    def source_context
      @source_context ||= selection_context || request_context
    end

    def request_context
      transaction_filter_context.merge(search_filter_context).with_indifferent_access
    end

    def transaction_filter_context
      values_from(transaction_filters, *TRANSACTION_FILTER_KEYS).merge(
        active_month_years: params[:active_month_years],
        default_year: params[:default_year]
      )
    end

    def search_filter_context
      values_from(search_filters, *SEARCH_FILTER_KEYS)
    end

    def resolved_user_card
      @resolved_user_card ||=
        if selection_context.present?
          current_user.user_cards.find_by(id: selected_user_card_id_from_selection)
        else
          user_card
        end
    end

    def selected_user_card_id_from_selection
      selection_context[:user_card_id].presence || selection_context.dig(:user_card, :id) || selection_context.dig("user_card", "id")
    end

    def default_active_month_years_for(today:, max_date:)
      if resolved_user_card && max_date > today
        [ resolved_reference_date(today:, max_date:).strftime("%Y%m").to_i ]
      else
        [ [ today, max_date ].min.strftime("%Y%m").to_i ]
      end
    end

    def resolved_reference_date(today:, max_date:)
      next_reference = current_context.references.where(
        user_card: resolved_user_card,
        reference_closing_date: [ Date.tomorrow.. ]
      ).order(:reference_closing_date).first

      next_reference.present? ? Date.new(next_reference.year, next_reference.month) : [ today, max_date ].min
    end

    def active_month_years_for(max_date:, today:)
      return compact_array_to_integers(source_context[:active_month_years]) if selection_context.present?
      return months_for_all_month_years if params[:all_month_years]

      parse_active_month_years(params[:active_month_years]).presence || default_active_month_years_for(today:, max_date:)
    end

    def months_for_all_month_years
      associations = association_filters
      relation = card_installments
      relation = relation.joins(card_transaction: associations.keys).where(card_transaction: associations) if associations.present?

      relation.map { |installment| month_year_value(installment.year, installment.month) }.uniq
    end

    def association_filters
      {}.tap do |associations|
        category_ids = compact_array(source_context[:category_id])
        entity_ids = compact_array(source_context[:entity_id])
        associations[:categories] = { id: category_ids } if category_ids.present?
        associations[:entities] = { id: entity_ids } if entity_ids.present?
      end
    end

    def default_year_for(active_month_years:, max_date:, today:)
      explicit_default = source_context[:default_year].presence || params[:default_year]
      return explicit_default.to_i if explicit_default.present?
      return active_month_years.max.to_s.first(4).to_i if active_month_years.any?

      [ max_date, today ].min.year
    end

    def count_by_month_year_for(state)
      Logic::CardInstallments.find_count_based_on_search(
        current_context,
        transaction_filters_for_count,
        search_filters_for_count(state)
      )
    end

    def transaction_filters_for_count
      compact_filter_context.merge(user_card_id: resolved_user_card&.id || [])
    end

    def search_filters_for_count(state)
      values_from(source_context, :search_term, *RANGE_FILTER_KEYS, :force_mobile, :exchange_bound_type).merge(
        sort: state[:sort],
        direction: state[:direction]
      )
    end
  end
end
