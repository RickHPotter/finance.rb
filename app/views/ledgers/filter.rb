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
      class: "w-full rounded-2xl border border-slate-200 bg-white p-4 shadow-sm dark:border-slate-800 dark:bg-slate-900",
      data: { controller: "reactive-form", turbo_frame: "_top", turbo_action: "replace" }
    ) do
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
        paid_filters if ledger_context[:kind] == :cash
      end

      canonical_hidden_fields
    end
  end

  private

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
    hidden_field_tag :sort, ledger_context[:sort]
    hidden_field_tag :direction, ledger_context[:direction]
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
