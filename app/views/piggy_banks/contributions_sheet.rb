# frozen_string_literal: true

class Views::PiggyBanks::ContributionsSheet < Views::Base
  include TranslateHelper
  include ComponentsHelper

  attr_reader :return_cash_transaction

  def initialize(return_cash_transaction:)
    @return_cash_transaction = return_cash_transaction
  end

  def view_template
    Popover(options: { trigger: "click", placement: "bottom-start" }, class: "relative z-40 shrink-0") do
      PopoverTrigger(class: "flex") do
        Button(type: :button, class: secondary_submit_row_button_class("min-w-64")) do
          action_message(:index)
        end
      end

      PopoverContent(class: "z-40 opacity-100! min-w-64 p-1") do
        div(class: "flex flex-col gap-1") do
          contributions_sheet
          investments_sheet
        end
      end
    end
  end

  private

  def contributions_sheet
    Sheet do
      SheetTrigger do
        Button(type: :button, variant: :ghost, class: sheet_menu_item_button_class, id: "piggy_bank_contributions_sheet_trigger") do
          sheet_menu_label(pluralise_model(CashTransaction, contribution_links.size), contribution_links.size)
        end
      end

      SheetContent(side: :middle, class: "flex max-h-[90vh] w-full flex-col md:w-1/3") do
        SheetHeader do
          SheetTitle { I18n.t("piggy_banks.contributions", count: contribution_links.size) }
          SheetDescription { return_cash_transaction.description }
        end

        SheetMiddle(class: "flex-1 overflow-y-auto") do
          SheetMiddle do
            contribution_month_groups.each do |month_year, installments|
              render Views::CashTransactions::MonthYear.new(
                mobile: true,
                month_year:,
                cash_installments: installments,
                budgets: [],
                index_context: { force_mobile: true, frame_prefix: "piggy_bank_cash_month_year" }
              )
            end
          end
        end
      end
    end
  end

  def investments_sheet
    Sheet do
      SheetTrigger do
        Button(type: :button, variant: :ghost, class: sheet_menu_item_button_class, id: "piggy_bank_investments_sheet_trigger") do
          sheet_menu_label(pluralise_model(Investment, investments.size), investments.size)
        end
      end

      SheetContent(side: :middle, class: "flex max-h-[90vh] w-full flex-col md:w-1/3") do
        SheetHeader do
          SheetTitle { pluralise_model(Investment, investments.size) }
          SheetDescription { return_cash_transaction.description }
        end

        SheetMiddle(class: "flex-1 overflow-y-auto") do
          if investment_relation.empty?
            empty_state
          else
            SheetMiddle do
              investment_month_scopes.each do |month_year, month_year_str, scope|
                render Views::Investments::MonthYear.new(
                  mobile: true,
                  month_year: "piggy_bank_investment_#{month_year}",
                  month_year_str:,
                  investments: scope,
                  current_user: return_cash_transaction.user
                )
              end
            end
          end
        end
      end
    end
  end

  def contribution_links
    @contribution_links ||= return_cash_transaction.piggy_bank_return_links
                                                   .includes(source_cash_transaction: [ :cash_installments,
                                                                                        { category_transactions: :category },
                                                                                        { entity_transactions: :entity } ])
                                                   .order(:created_at, :id).to_a
  end

  def contribution_month_groups
    installments = contribution_links.flat_map { |link| link.source_cash_transaction.cash_installments }
    installments.group_by do |installment|
      Kernel.format("%<year>04d%<month>02d", year: installment.year, month: installment.month)
    end
                .sort_by(&:first)
                .reverse
  end

  def investment_relation
    @investment_relation ||= return_cash_transaction.piggy_bank_investments.includes(:investment_type, user_bank_account: :bank)
  end

  def investment_month_scopes
    investment_relation.reorder(nil).distinct.order(year: :desc, month: :desc).pluck(:year, :month).map do |year, month|
      date = Date.new(year, month, 1)
      [
        date.strftime("%Y%m"),
        I18n.l(date, format: "%b %Y"),
        investment_relation.where(year:, month:).order(:date, :id)
      ]
    end
  end

  def investments
    @investments ||= investment_relation.to_a
  end

  def sheet_menu_label(label, count)
    div(class: "flex w-full items-center justify-between gap-3") do
      span { label }
      span(class: "rounded-full bg-slate-200 px-2 py-0.5 text-xs font-bold text-slate-700") { count }
    end
  end

  def empty_state
    p(class: "py-8 text-center text-sm text-slate-500") { I18n.t("piggy_banks.no_investments") }
  end

  def sheet_menu_item_button_class
    "w-full justify-start rounded-md px-3 py-2 text-left text-sm font-semibold text-slate-700 hover:bg-slate-100 " \
      "dark:text-slate-200 dark:hover:bg-slate-800"
  end
end
