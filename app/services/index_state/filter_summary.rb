# frozen_string_literal: true

module IndexState
  class FilterSummary
    PARAM_ROOTS = {
      card_transactions: :card_transaction,
      cash_transactions: :cash_transaction,
      budgets: :budget
    }.freeze

    attr_reader :surface, :index_context

    def initialize(surface:, index_context:)
      @surface = surface.to_sym
      @index_context = index_context.with_indifferent_access
    end

    def to_h
      items = build_items

      {
        active: items.any?,
        items:
      }
    end

    private

    def build_items
      base_items + cash_items
    end

    def param_root
      @param_root ||= PARAM_ROOTS[surface]
    end

    def count_for(key)
      Array(index_context[key]).flatten.compact_blank.size
    end

    def range_active?(from_key, to_key)
      index_context[from_key].present? || index_context[to_key].present?
    end

    def paid_state_active?
      index_context[:paid_state].present? && index_context[:paid_state] != "all"
    end

    def exchange_bound_type_active?
      index_context[:exchange_bound_type].present? && index_context[:exchange_bound_type] != "all"
    end

    def item(label:, remove:)
      { label:, remove: }
    end

    def root_item(key, label)
      item(label:, remove: [ [ key ] ])
    end

    def nested_item(key, label)
      item(label:, remove: [ [ param_root, key ] ])
    end

    def range_item(label_key:, from_key:, to_key:, formatter: nil)
      item(
        label: I18n.t(label_key, value: formatted_range(from_key, to_key, formatter:)),
        remove: [ [ from_key ], [ to_key ] ]
      )
    end

    def base_items
      [].tap do |items|
        append_search_term_item(items)
        append_category_item(items)
        append_entity_item(items)
        append_exchange_bound_type_item(items)
        append_transaction_price_item(items)
        append_installment_price_item(items)
        append_installments_count_item(items)
      end
    end

    def cash_items
      return [] unless surface == :cash_transactions

      [].tap do |items|
        if range_active?(:from_date, :to_date)
          items << range_item(label_key: "filters.summary.items.date_range", from_key: :from_date, to_key: :to_date, formatter: :date)
        end
        if paid_state_active?
          items << item(
            label: I18n.t("filters.summary.items.paid_state", value: I18n.t("filters.paid_state.#{index_context[:paid_state]}")),
            remove: [ [ :paid_state ], [ :paid ], [ :pending ] ]
          )
        end
        items << nested_item(:user_bank_account_id, account_summary) if count_for(:user_bank_account_id).positive?
      end
    end

    def append_search_term_item(items)
      return unless index_context[:search_term].present?

      items << root_item(:search_term, I18n.t("filters.summary.items.search_term", value: index_context[:search_term]))
    end

    def append_category_item(items)
      return unless count_for(:category_id).positive?

      items << nested_item(:category_id, I18n.t("filters.summary.items.categories", count: count_for(:category_id)))
    end

    def append_entity_item(items)
      return unless count_for(:entity_id).positive?

      items << nested_item(:entity_id, I18n.t("filters.summary.items.entities", count: count_for(:entity_id)))
    end

    def append_exchange_bound_type_item(items)
      return unless exchange_bound_type_active?

      items << item(
        label: I18n.t("filters.summary.items.exchange_bound_type", value: I18n.t("filters.exchange_bound_type.#{index_context[:exchange_bound_type]}")),
        remove: [ [ :exchange_bound_type ] ]
      )
    end

    def append_transaction_price_item(items)
      return unless range_active?(:from_ct_price, :to_ct_price)

      items << range_item(label_key: "filters.summary.items.transaction_price", from_key: :from_ct_price, to_key: :to_ct_price, formatter: :currency)
    end

    def append_installment_price_item(items)
      return unless range_active?(:from_price, :to_price)

      items << range_item(label_key: "filters.summary.items.installment_price", from_key: :from_price, to_key: :to_price, formatter: :currency)
    end

    def append_installments_count_item(items)
      return unless range_active?(:from_installments_count, :to_installments_count)

      items << range_item(label_key: "filters.summary.items.installments_count", from_key: :from_installments_count, to_key: :to_installments_count)
    end

    def account_summary
      I18n.t("filters.summary.items.account", count: count_for(:user_bank_account_id))
    end

    def formatted_range(from_key, to_key, formatter: nil)
      from_value = format_value(index_context[from_key], formatter:)
      to_value = format_value(index_context[to_key], formatter:)

      "#{from_value || '...'} -> #{to_value || '...'}"
    end

    def format_value(value, formatter:)
      return if value.blank?

      case formatter
      when :currency
        ApplicationController.helpers.number_to_currency(value.to_i / 100.0, unit: "R$", precision: 2, locale: I18n.locale)
      when :date
        I18n.l(value.to_date)
      else
        value.to_s
      end
    end
  end
end
