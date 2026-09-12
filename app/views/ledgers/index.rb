# frozen_string_literal: true

class Views::Ledgers::Index < Views::Base
  attr_reader :ledger_context

  def initialize(context:)
    @ledger_context = context
  end

  def view_template
    turbo_frame_tag "center_container" do
      div(class: "w-full text-slate-950 dark:text-slate-100") do
        render Views::Ledgers::AggregateTotal.new(amount: ledger_context[:aggregate_total_amount])
        render Views::Ledgers::Header.new(header: ledger_context[:header])
        if ledger_context[:external]
          render Views::Ledgers::ModeTabs.new(kind: ledger_context[:kind], cash_path: ledger_context[:cash_path], card_path: ledger_context[:card_path])
        end
        render Views::Ledgers::Filter.new(context: ledger_context)
        render Views::Ledgers::MonthContainer.new(context: ledger_context)
      end
    end
  end
end
