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
          contribution_lots_list
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

  def contribution_lots_list
    return if contribution_links.empty?

    div(class: "space-y-2 border-b border-slate-200 p-4 dark:border-slate-800") do
      p(class: "text-2xs font-bold uppercase tracking-[0.18em] text-slate-500 dark:text-slate-400") do
        I18n.t("piggy_banks.return_section.contributions_title")
      end
      contribution_links.each do |link|
        source = link.source_cash_transaction
        next if source.blank?

        div(class: "rounded-lg border border-slate-200 bg-white p-3 shadow-xs dark:border-slate-800 dark:bg-slate-900/60") do
          div(class: "flex items-start justify-between gap-2") do
            div(class: "min-w-0 flex-1 space-y-1") do
              div(class: "flex items-center gap-2 flex-wrap") do
                p(class: "truncate text-sm font-bold text-slate-950 dark:text-slate-100") do
                  source.description
                end
                lot_status_badge(link)
              end
              div(class: "flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-slate-500 dark:text-slate-400") do
                span do
                  "#{I18n.t('piggy_banks.lot.contributed_label')}: #{I18n.l(source.date.to_date, format: :short)}"
                end
                span do
                  if link.iof_exempt_on.present?
                    "#{I18n.t('piggy_banks.lot.iof_free_label')}: #{I18n.l(link.iof_exempt_on, format: :short)}"
                  else
                    "#{I18n.t('piggy_banks.lot.iof_free_label')}: #{I18n.t('piggy_banks.iof_status.not_recorded')}"
                  end
                end
              end
            end
            div(class: "shrink-0 text-right") do
              p(class: "font-mono text-sm font-bold text-slate-950 dark:text-slate-100") do
                money(link.return_price)
              end
              p(class: "text-2xs uppercase tracking-wider text-slate-400 dark:text-slate-500") do
                I18n.t("piggy_banks.return_section.baseline")
              end
            end
          end
        end
      end
    end
  end

  def lot_status_badge(link)
    status = link.iof_status
    label = I18n.t("piggy_banks.iof_status.#{status}")
    classes =
      case status
      when :available
        "bg-emerald-100 text-emerald-800 dark:bg-emerald-950/60 dark:text-emerald-300"
      when :waiting
        "bg-amber-100 text-amber-800 dark:bg-amber-950/60 dark:text-amber-300"
      else
        "bg-slate-100 text-slate-700 dark:bg-slate-800 dark:text-slate-300"
      end

    span(
      class: "inline-flex items-center rounded-full px-2 py-0.5 text-2xs font-bold uppercase tracking-[0.14em] #{classes}",
      data: { piggy_bank_iof_status: status.to_s }
    ) { label }
  end

  def money(value) = from_cent_based_to_float(value, "R$")
end
