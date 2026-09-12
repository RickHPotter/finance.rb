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
        class: "absolute -top-5 right-4 rounded-b-lg border border-yellow-600 bg-yellow-400 px-3 py-2 font-lekton text-sm font-bold text-black shadow-md",
        data: { ledger_aggregate_total: true, price: amount }
      ) do
        from_cent_based_to_float(amount, "R$")
      end
    end
  end
end
