# frozen_string_literal: true

class Views::Shared::MonthYearHeader < Views::Base
  include TranslateHelper

  attr_reader :month_year_str, :total_amount, :mobile, :total_id

  def initialize(month_year_str:, total_amount:, mobile:, total_id: :priceSum)
    @month_year_str = month_year_str
    @total_amount = total_amount
    @mobile = mobile
    @total_id = total_id
  end

  def view_template
    div(class: header_class) do
      div(class: "flex gap-2 absolute left-0 bottom-4") do
        span(class: label_class) { month_year_str }

        span(class: total_class, id: total_id, data: { price: total_amount }) do
          from_cent_based_to_float(total_amount, "R$")
        end
      end

      yield if block_given?
    end
  end

  private

  def header_class
    mobile ? "pb-2 pt-6 text-slate-800 flex gap-2 relative" : "pb-2 pt-4 text-slate-800 flex gap-2 relative"
  end

  def label_class
    if mobile
      "text-sm bg-blue-200 text-blue-900 border border-blue-600 py-1 px-2 rounded-lg"
    else
      "text-sm bg-blue-200 text-blue-900 border border-blue-600 px-4 py-2 rounded-lg"
    end
  end

  def total_class
    if mobile
      "text-sm bg-red-200 text-red-900 border border-red-600 py-1 px-2 rounded-lg"
    else
      "text-sm bg-red-200 text-red-900 border border-red-600 px-4 py-2 rounded-lg"
    end
  end
end
