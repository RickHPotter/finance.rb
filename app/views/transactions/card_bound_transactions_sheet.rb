# frozen_string_literal: true

class Views::Transactions::CardBoundTransactionsSheet < Views::Base
  include TranslateHelper

  attr_reader :label, :installments, :user_card_id

  def initialize(label:, installments:, user_card_id: nil)
    @label = label
    @installments = installments
    @user_card_id = user_card_id
  end

  def view_template
    div(class: "space-y-4") do
      div(class: "mb-5 mt-1") do
        span(class: "rounded-full border border-slate-300 bg-slate-100 px-4 py-1 text-sm font-bold uppercase tracking-wide text-slate-700") do
          label
        end
      end

      grouped_installments.each do |month_year, month_installments|
        month_year_date = Date.parse("#{month_year[0..3]}-#{month_year[4..]}-01")

        div(class: "mb-8") do
          fieldset(class: "grid grid-cols-1 border border-slate-200 rounded-lg px-2 mb-4") do
            render Views::Shared::MonthYearHeader.new(
              month_year_str: I18n.l(month_year_date, format: "%B %Y"),
              total_amount: month_installments.sum(&:price),
              mobile: true
            )

            render Views::CardInstallments::Index.new(
              mobile: true,
              card_installments: month_installments,
              user_card_id:,
              entity_links: false
            )
          end
        end
      end
    end
  end

  private

  def grouped_installments
    installments
      .group_by { |installment| Date.new(installment.year, installment.month, 1).strftime("%Y%m") }
      .sort_by { |month_year, _| month_year.to_i }
      .reverse
  end
end
