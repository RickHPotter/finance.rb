# frozen_string_literal: true

class Views::Ledgers::AggregateTotal < Views::Base
  include TranslateHelper

  attr_reader :amount

  def initialize(amount:)
    @amount = amount
  end

  def view_template
    div(class: "relative z-40 h-0") do
      div(
        class: "absolute -top-12 right-0 rounded-t-lg border border-yellow-600 bg-yellow-400 px-3 py-2 font-lekton text-sm font-bold text-black shadow-md sm:right-2",
        data: { ledger_aggregate_total: true, price: amount }
      ) do
        from_cent_based_to_float(amount, "R$")
      end
    end
  end
end
