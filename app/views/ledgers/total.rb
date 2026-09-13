# frozen_string_literal: true

class Views::Ledgers::Total < Views::Base
  include TranslateHelper

  attr_reader :count, :amount

  def initialize(count:, amount:)
    @count = count
    @amount = amount
  end

  def view_template
    div(class: "mt-3 flex flex-col gap-2 rounded-xl bg-slate-100 px-4 py-3 text-sm sm:flex-row sm:items-center sm:justify-between dark:bg-slate-800") do
      span(class: "font-medium text-slate-600 dark:text-slate-300") { I18n.t("ledgers.total.entries", count:) }
      span(class: "font-bold text-slate-950 dark:text-white", data: { ledger_total: true, price: amount }) do
        from_cent_based_to_float(amount, "R$")
      end
    end
  end
end
