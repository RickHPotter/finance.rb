# frozen_string_literal: true

class Views::Ledgers::MonthContainer < Views::Base
  attr_reader :ledger_context

  def initialize(context:)
    @ledger_context = context
  end

  def view_template
    turbo_frame_tag "month_year_container" do
      ledger_context[:active_month_years].sort.each do |month_year|
        turbo_frame_tag(
          "month_year_container_#{month_year}",
          src: month_path(month_year),
          loading: :lazy
        )
      end
    end
  end

  private

  def month_path(month_year)
    query = {
      month_year:,
      search_term: ledger_context[:search_term].presence,
      paid: (ledger_context[:paid] if ledger_context[:kind] == :cash),
      pending: (ledger_context[:pending] if ledger_context[:kind] == :cash),
      sort: ledger_context[:sort],
      direction: ledger_context[:direction],
      page: ledger_context[:page],
      per_page: ledger_context[:per_page],
      force_mobile: (true if ledger_context[:force_mobile])
    }.compact
    add_internal_filter(query)

    "#{ledger_context[:month_path]}?#{Rack::Utils.build_nested_query(query)}"
  end

  def add_internal_filter(query)
    return if ledger_context[:external]

    if ledger_context[:kind] == :cash && ledger_context[:user_bank_account_id].present?
      query[:cash_transaction] = { user_bank_account_id: ledger_context[:user_bank_account_id] }
    elsif ledger_context[:kind] == :card && ledger_context[:user_card_id].present?
      query[:card_transaction] = { user_card_id: ledger_context[:user_card_id] }
    end
  end
end
