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
      class: "grid grid-cols-7 gap-2 border-b border-slate-200 #{cycle('bg-gray-100', 'bg-gray-200')} hover:bg-white " \
             "dark:border-slate-700 dark:bg-slate-900 dark:text-slate-100 dark:hover:bg-slate-800",
      data: { id: user_bank_account.id, datatable_target: :row }
    ) do
      div(class: "col-span-2 px-3 py-3 flex items-center mx-auto font-lekton font-semibold") do
        link_to user_bank_account_path(user_bank_account),
                class: "user_bank_account_description px-4 whitespace-nowrap hover:underline",
                data: { turbo_frame: "_top", turbo_prefetch: false } do
          user_bank_account.pretty_label
        end
      end

      div(class: "flex items-center justify-center px-2 py-3 text-sm font-semibold text-slate-700 dark:text-slate-300") do
        status_badge
      end

      div(class: "jump_to_cash_transactions px-2 py-3 flex items-center justify-center mx-auto font-anonymous font-semibold whitespace-nowrap ml-auto") do
        if user_bank_account.cash_transactions_count.positive?
          link_to(
            user_bank_account.cash_transactions_count,
            cash_transactions_path(cash_transaction: { user_bank_account_id: user_bank_account.id }, all_month_years: true),
            class: "text-indigo-600 hover:underline dark:text-sky-300",
            data: { turbo_frame: "_top", turbo_prefetch: false }
          )
        else
          span { user_bank_account.cash_transactions_count }
        end
      end

      div(class: "flex items-center justify-center px-2 py-3 text-lg whitespace-nowrap ml-auto") do
        span do
          from_cent_based_to_float(user_bank_account.cash_transactions_total, "R$")
        end
      end
      div(class: "flex items-center justify-center px-2 py-3 font-lekton text-lg whitespace-nowrap ml-auto") do
        span do
          from_cent_based_to_float(user_bank_account.balance, "R$")
        end
      end

      div(class: "flex items-center justify-center px-2 py-3") do
        div(class: "flex items-center justify-end gap-1") do
          link_to(edit_user_bank_account_path(user_bank_account), id: "edit_user_bank_account_#{user_bank_account.id}",
                                                                  class: action_button_class,
                                                                  title: action_message(:edit),
                                                                  aria: { label: action_message(:edit) },
                                                                  data: { turbo_frame: "_top", turbo_prefetch: false }) { cached_icon(:pencil) }

          LinkWithConfirmation(
            id: user_bank_account.id,
            icon: :destroy,
            link_params: {
              href: user_bank_account_path(user_bank_account),
              size: :xs,
              id: "delete_user_bank_account_#{user_bank_account.id}",
              class: destructive_action_button_class,
              data: { turbo_method: :delete }
            }
          )
        end
      end
    end
  end

  def mobile_row
    div(class: "mx-2 rounded-lg bg-slate-100 shadow-sm overflow-hidden my-3 dark:bg-slate-900 dark:text-slate-100",
        data: { id: user_bank_account.id, datatable_target: :row }) do
      div(class: "p-4 bg-linear-to-r from-blue-300 via-blue-500 to-blue-700") do
        div(class: "flex items-center justify-between") do
          div(class: "flex items-center space-x-3") do
            cached_icon :money

            link_to(
              user_bank_account.user_bank_account_name,
              user_bank_account_path(user_bank_account),
              id: "show_user_bank_account_#{user_bank_account.id}",
              class: "text-lg font-semibold text-black underline underline-offset-[3px]",
              data: { turbo_frame: "_top" }
            )
          end
          status_badge
        end
      end

      div(class: "p-4") do
        div(class: "grid grid-cols-2 gap-4 my-2") do
          div(class: "space-y-1") do
            div(class: "flex items-center space-x-2") do
              cached_icon :number
              span(class: "text-sm font-medium text-slate-500 dark:text-slate-400") { pluralise_model(CashTransaction, 2) }
            end

            div(class: "flex items-center") { span(class: "text-sm font-semibold text-slate-800 dark:text-slate-100") { user_bank_account.cash_transactions_count } }
          end

          div(class: "space-y-1") do
            div(class: "flex items-center space-x-2") do
              cached_icon :money
              span(class: "text-sm font-medium text-slate-500 dark:text-slate-400") { model_attribute(CashTransaction, :total_amount) }
            end

            div(class: "flex items-center") do
              span(class: "text-sm font-semibold text-slate-800 mr-auto dark:text-slate-100") do
                from_cent_based_to_float(user_bank_account.cash_transactions_total, "R$")
              end
            end
          end
        end

        div(class: "mt-4 flex justify-end border-t border-slate-200 pt-3 dark:border-slate-700") do
          Button(
            link: cash_transactions_path(cash_transaction: { user_bank_account_id: user_bank_account.id }, all_month_years: true),
            variant: :outline,
            class: "border-slate-300 text-slate-700 hover:bg-slate-100 dark:border-slate-700 dark:text-slate-300 dark:hover:bg-slate-800",
            data: { turbo_frame: "_top", turbo_prefetch: false }
          ) do
            span(class: "inline-flex items-center gap-2") do
              cached_icon(:jump_to)
              plain pluralise_model(CashTransaction, 2)
            end
          end
        end
      end
    end
  end

  def action_button_class
    "inline-flex size-6 items-center justify-center rounded-sm border border-sky-200 bg-sky-50 text-sky-700 " \
      "shadow-sm transition hover:border-sky-600 hover:bg-sky-600 hover:text-white dark:border-slate-600 dark:bg-slate-900 " \
      "dark:text-sky-300 dark:hover:border-sky-500 dark:hover:bg-slate-800 [&_svg]:size-4"
  end

  def destructive_action_button_class
    "inline-flex size-6 items-center justify-center rounded-sm border border-red-200 bg-white text-red-700 " \
      "shadow-sm transition hover:border-red-600 hover:bg-red-600 hover:text-white dark:border-slate-600 dark:bg-slate-900 " \
      "dark:text-red-300 dark:hover:border-red-500 dark:hover:bg-slate-800 [&_svg]:size-4 [&_svg]:!text-current"
  end

  def status_badge
    colour = user_bank_account.active? ? "bg-emerald-100 text-emerald-800" : "bg-slate-200 text-slate-700"

    span(class: "rounded-full px-2.5 py-1 text-xs font-semibold uppercase tracking-wide #{colour}") do
      model_attribute(UserBankAccount, "statuses.#{user_bank_account.active? ? :active : :inactive}")
    end
  end
end
