# frozen_string_literal: true

class Views::UserBankAccounts::UserBankAccount < Views::Base
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::DOMID
  include Phlex::Rails::Helpers::Cycle

  include CacheHelper
  include TranslateHelper

  attr_reader :user_bank_account, :mobile

  def initialize(user_bank_account:, mobile: false)
    @user_bank_account = user_bank_account
    @mobile = mobile
  end

  def view_template
    turbo_frame_tag dom_id(user_bank_account) do
      mobile ? mobile_row : desktop_row
    end
  end

  private

  def desktop_row
    div(
      class: "grid grid-cols-6 gap-2 border-b border-slate-200 #{cycle('bg-gray-100', 'bg-gray-200')} hover:bg-white",
      data: { id: user_bank_account.id, datatable_target: :row }
    ) do
      div(class: "col-span-2 px-1 flex items-center mx-auto font-lekton font-semibold") do
        span(class: "user_bank_account_description px-4 whitespace-nowrap") { user_bank_account.pretty_label }
      end

      div(class: "jump_to_cash_transactions px-1 flex items-center justify-center mx-auto font-anonymous font-semibold whitespace-nowrap ml-auto") do
        if user_bank_account.cash_transactions_count.positive?
          link_to(
            user_bank_account.cash_transactions_count,
            cash_transactions_path(cash_transaction: { user_bank_account_id: user_bank_account.id }, all_month_years: true),
            class: "text-indigo-600 hover:underline",
            data: { turbo_frame: :_top, turbo_prefetch: false }
          )
        else
          span { user_bank_account.cash_transactions_count }
        end
      end

      div(class: "flex items-center justify-center text-lg whitespace-nowrap ml-auto") do
        span do
          from_cent_based_to_float(user_bank_account.cash_transactions_total, "R$")
        end
      end
      div(class: "flex items-center justify-center font-lekton text-lg whitespace-nowrap ml-auto") do
        span do
          from_cent_based_to_float(user_bank_account.balance, "R$")
        end
      end

      div(class: "flex items-center justify-center") do
        div(class: "flex items-center justify-center px-2 my-1 rounded-md") do
          link_to(edit_user_bank_account_path(user_bank_account), id: "edit_user_bank_account_#{user_bank_account.id}",
                                                                  class: "text-blue-600 hover:text-blue-800 mx-2 bg-sky-200 rounded-4xl",
                                                                  data: { turbo_frame: :_top }) { cached_icon(:pencil) }

          link_to(user_bank_account_path(user_bank_account), id: "delete_user_bank_account_#{user_bank_account.id}",
                                                             class: "text-red-600 hover:text-red-800 mx-2 bg-rose-200 rounded-4xl",
                                                             data: { turbo_method: :delete, turbo_confirm: I18n.t("confirmation.sure") }) { cached_icon(:destroy) }
        end
      end
    end
  end

  def mobile_row
    div(class: "rounded-lg shadow-sm overflow-hidden my-3 bg-slate-100", data: { id: user_bank_account.id, datatable_target: :row }) do
      div(class: "p-4 bg-gradient-to-r from-blue-300 via-blue-500 to-blue-700") do
        div(class: "flex items-center justify-between") do
          div(class: "flex items-center space-x-3") do
            cached_icon :money

            link_to(
              user_bank_account.user_bank_account_name,
              edit_user_bank_account_path(user_bank_account),
              id: "edit_user_bank_account_#{user_bank_account.id}",
              class: "text-lg font-semibold text-black underline underline-offset-[3px]",
              data: { turbo_frame: :_top }
            )
          end

          link_to(cash_transactions_path(cash_transaction: { user_bank_account_id: user_bank_account.id }, all_month_years: true),
                  data: { turbo_frame: :_top, turbo_prefetch: false }) { cached_icon(:jump_to) }
        end
      end

      div(class: "p-4") do
        div(class: "grid grid-cols-2 gap-4 my-2") do
          div(class: "space-y-1") do
            div(class: "flex items-center space-x-2") do
              cached_icon :number
              span(class: "text-sm font-medium text-slate-500") { pluralise_model(CashTransaction, 2) }
            end

            div(class: "flex items-center") { span(class: "text-sm font-semibold text-slate-800") { user_bank_account.cash_transactions_count } }
          end

          div(class: "space-y-1") do
            div(class: "flex items-center space-x-2") do
              cached_icon :money
              span(class: "text-sm font-medium text-slate-500") { model_attribute(CashTransaction, :total_amount) }
            end

            div(class: "flex items-center") do
              span(class: "text-sm font-semibold text-slate-800 mr-auto") { from_cent_based_to_float(user_bank_account.cash_transactions_total, "R$") }
            end
          end
        end
      end
    end
  end
end
