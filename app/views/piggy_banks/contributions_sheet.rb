# frozen_string_literal: true

class Views::PiggyBanks::ContributionsSheet < Views::Base
  include Phlex::Rails::Helpers::LinkTo

  include TranslateHelper
  include ComponentsHelper

  attr_reader :return_cash_transaction

  def initialize(return_cash_transaction:)
    @return_cash_transaction = return_cash_transaction
  end

  def view_template
    Sheet do
      SheetTrigger do
        Button(type: :button, class: secondary_submit_row_button_class("min-w-64")) do
          I18n.t("piggy_banks.contributions", count: contribution_links.size)
        end
      end

      SheetContent(side: :middle, class: "flex max-h-[90vh] w-full flex-col md:w-1/3") do
        SheetHeader do
          SheetTitle { I18n.t("piggy_banks.contributions", count: contribution_links.size) }
          SheetDescription { return_cash_transaction.description }
        end

        SheetMiddle(class: "flex-1 overflow-y-auto") do
          div(class: "space-y-3 py-2") do
            contribution_links.each { |link| contribution_card(link) }
          end
        end
      end
    end
  end

  private

  def contribution_links
    @contribution_links ||= return_cash_transaction.piggy_bank_return_links.includes(source_cash_transaction: :cash_installments).order(:created_at, :id).to_a
  end

  def contribution_card(link)
    source = link.source_cash_transaction

    link_to edit_cash_transaction_path(source),
            class: "block rounded-md border border-slate-200 bg-white p-3 text-slate-950 transition hover:border-sky-400 hover:bg-sky-50",
            data: { turbo_frame: "_top", turbo_prefetch: false },
            id: "piggy_bank_contribution_#{link.id}" do
      div(class: "flex items-start justify-between gap-3") do
        div(class: "min-w-0") do
          p(class: "truncate text-sm font-bold") { source.description }
          p(class: "mt-1 text-xs text-slate-500") { I18n.l(source.date, format: :short) }
        end

        p(class: "shrink-0 text-sm font-bold") { from_cent_based_to_float(link.return_price, "R$") }
      end
    end
  end
end
