# frozen_string_literal: true

class Views::Subscriptions::CashTransactionFields < Views::Base
  include CacheHelper
  include TranslateHelper

  attr_reader :form, :user_bank_accounts, :cash_transaction

  def initialize(form:, user_bank_accounts:)
    @form = form
    @user_bank_accounts = user_bank_accounts
    @cash_transaction = form.object
  end

  def view_template
    div(
      class: "nested-form-wrapper rounded-lg border border-emerald-200 bg-emerald-50 p-2 #{'hidden' if cash_transaction.marked_for_destruction?}",
      data: {
        new_record: cash_transaction.new_record?,
        transaction_type: :cash,
        sort_month_year:,
        sort_date:,
        sort_description: cash_transaction.description.to_s.downcase
      }
    ) do
      form.hidden_field :date
      form.hidden_field :user_bank_account_id
      form.hidden_field :price, data: { subscription_transactions_target: "transactionPriceInput" }

      div(class: "flex items-start justify-between gap-3") do
        div(class: "min-w-0 flex-1") do
          p(class: "text-xs font-semibold uppercase tracking-wide text-emerald-700", data: { role: "ref-month-year-display" }) { ref_month_year }
          p(class: "text-sm font-semibold text-slate-900", data: { role: "date-display" }) { formatted_date }
        end

        div(class: "min-w-0 flex-1") do
          p(class: "truncate text-sm text-slate-600", data: { role: "account-display" }) { account_name }
          p(class: "text-sm font-semibold text-slate-800", data: { role: "price-display" }) { formatted_price }
        end

        div(class: "flex items-center gap-2") do
          button(
            type: :button,
            class: "rounded border border-sky-200 bg-sky-50 p-2 text-sky-700 hover:bg-sky-100",
            data: { action: "subscription-transactions#editRow" }
          ) { cached_icon(:pencil) }

          button(
            type: :button,
            class: "rounded border border-red-300 bg-red-50 p-2 text-red-700 hover:bg-red-100",
            data: { action: "subscription-transactions#removeRow nested-form#remove" }
          ) { cached_icon(:destroy) }
        end
      end

      form.hidden_field :id if cash_transaction.persisted?
      form.hidden_field :_destroy
    end
  end

  private

  def account_name
    user_bank_accounts.find { |(_, id)| id == cash_transaction.user_bank_account_id }&.first || model_attribute(CashTransaction, :user_bank_account_id)
  end

  def formatted_date
    cash_transaction.date.present? ? I18n.l(cash_transaction.date.to_date, format: :long).upcase : "-"
  end

  def formatted_price
    from_cent_based_to_float(cash_transaction.price.to_i, "R$")
  end

  def ref_month_year
    cash_transaction.month.present? ? cash_transaction.month_year : "-"
  end

  def sort_month_year
    [ cash_transaction.year.to_i.to_s.rjust(4, "0"), cash_transaction.month.to_i.to_s.rjust(2, "0") ].join("-")
  end

  def sort_date
    cash_transaction.date&.to_date&.strftime("%Y-%m-%d")
  end
end
