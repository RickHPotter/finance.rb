# frozen_string_literal: true

class Views::Ledgers::Filter < Views::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::HiddenFieldTag

  attr_reader :ledger_context

  def initialize(context:)
    @ledger_context = context
  end

  def view_template
    form_with(
      url: ledger_context[:index_path],
      id: "search_form",
      method: :get,
      class: "relative w-full rounded-2xl border border-slate-200 bg-white p-4 shadow-sm dark:border-slate-800 dark:bg-slate-900",
      data: { controller: "reactive-form", turbo_frame: "_top", turbo_action: "replace" }
    ) do
      render Views::Ledgers::AggregateTotal.new(amount: ledger_context[:aggregate_total_amount])

      render Views::Shared::MonthYearSelector.new(
        current_user: (ledger_context[:current_user] unless ledger_context[:external]),
        default_year: ledger_context[:default_year],
        years: ledger_context[:years],
        active_month_years: ledger_context[:active_month_years],
        count_by_month_year: ledger_context[:count_by_month_year]
      )

      div(class: "mt-5 flex flex-col gap-3 sm:flex-row sm:items-center") do
        TextFieldTag(
          :search_term,
          svg: :magnifying_glass,
          clearable: true,
          placeholder: I18n.t("ledgers.filter.search"),
          value: ledger_context[:search_term],
          class: "flex-1",
          data: { controller: "cursor", action: "input->reactive-form#submitWithDelay" }
        )
        card_filter if ledger_context[:kind] == :card
        sort_controls
        paid_filters if ledger_context[:kind] == :cash
      end

      canonical_hidden_fields
    end
  end

  private

  def card_filter
    select(
      name: "card_transaction[user_card_id]",
      id: "ledger_user_card_id",
      class: "min-w-0 w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-800 sm:w-auto " \
             "dark:border-slate-700 dark:bg-slate-950 dark:text-slate-200",
      aria: { label: I18n.t("ledgers.filter.card") },
      data: { action: "change->reactive-form#submit" }
    ) do
      option(value: "", selected: ledger_context[:user_card_id].blank?) { I18n.t("ledgers.filter.all_cards") }
      ledger_context.fetch(:ledger_user_cards, []).each do |id, name|
        option(value: id, selected: ledger_context[:user_card_id] == id) { name }
      end
    end
  end

  def sort_controls
    div(class: "grid w-full grid-cols-2 gap-2 sm:flex sm:w-auto") do
      select(
        name: :sort,
        id: "ledger_sort",
        class: "min-w-0 w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-800 sm:w-auto " \
               "dark:border-slate-700 dark:bg-slate-950 dark:text-slate-200",
        aria: { label: I18n.t("ledgers.filter.sort") },
        data: { action: "change->reactive-form#submit" }
      ) do
        sort_options.each do |value, label|
          option(value:, selected: ledger_context[:sort] == value) { label }
        end
      end
      select(
        name: :direction,
        id: "ledger_direction",
        class: "min-w-0 w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-800 sm:w-auto " \
               "dark:border-slate-700 dark:bg-slate-950 dark:text-slate-200",
        aria: { label: I18n.t("ledgers.filter.direction") },
        data: { action: "change->reactive-form#submit" }
      ) do
        %w[asc desc].each do |value|
          option(value:, selected: ledger_context[:direction] == value) { I18n.t("ledgers.filter.directions.#{value}") }
        end
      end
    end
  end

  def sort_options
    values = %w[description installment_date transaction_date price]
    values.unshift("default") if ledger_context[:kind] == :cash
    values.map { |value| [ value, I18n.t("ledgers.filter.sorts.#{value}") ] }
  end

  def paid_filters
    div(class: "flex items-center gap-4 rounded-lg bg-slate-50 px-3 py-2 dark:bg-slate-950") do
      switch_with_label(:paid, ledger_context[:paid], I18n.t("ledgers.filter.paid"))
      switch_with_label(:pending, ledger_context[:pending], I18n.t("ledgers.filter.pending"))
    end
  end

  def switch_with_label(name, checked, label)
    label do
      span(class: "flex items-center gap-2 text-xs font-semibold text-slate-600 dark:text-slate-300") do
        Switch(name:, checked:, data: { action: "change->reactive-form#submit" })
        plain(label)
      end
    end
  end

  def canonical_hidden_fields
    hidden_field_tag :per_page, ledger_context[:per_page]
    hidden_field_tag :force_mobile, true if ledger_context[:force_mobile]
    return if ledger_context[:external]

    if ledger_context[:kind] == :cash && ledger_context[:user_bank_account_id].present?
      hidden_field_tag "cash_transaction[user_bank_account_id]", ledger_context[:user_bank_account_id]
    elsif ledger_context[:kind] == :card && ledger_context[:user_card_id].present?
      hidden_field_tag "card_transaction[user_card_id]", ledger_context[:user_card_id]
    end
  end
end
