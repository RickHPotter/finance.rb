# frozen_string_literal: true

class Views::UserBankAccounts::Index < Views::Base
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::TextFieldTag

  include TranslateHelper
  include CacheHelper

  attr_reader :user_bank_accounts, :mobile

  def initialize(user_bank_accounts:, mobile: false)
    @user_bank_accounts = user_bank_accounts
    @mobile = mobile
  end

  def view_template
    turbo_frame_tag :center_container do
      mobile ? mobile_index : desktop_index
    end
  end

  private

  def include_inactive?
    params[:include_inactive] == "false"
  end

  def desktop_index
    div(class: "flex justify-between mb-6 bg-white p-4 shadow-md rounded-lg") do
      link_to(
        action_model(:newa, UserBankAccount),
        new_user_bank_account_path,
        class: "py-2 px-3 rounded-sm border border-sky-900 bg-blue-600 hover:bg-blue-800 transition-colors text-white shadow-lg font-thin",
        data: { turbo_frame: "_top" }
      )

      link_to(
        include_inactive? ? action_message(:show_inactive) : action_message(:hide_inactive),
        user_bank_accounts_path(include_inactive: include_inactive?),
        class: "py-2 px-3 rounded-sm border border-sky-900 bg-blue-600 hover:bg-blue-800 transition-colors text-white shadow-lg font-thin",
        data: { turbo_frame: "_top" }
      )
    end

    div(class: "min-w-full") do
      turbo_frame_tag :user_bank_accounts do
        div(class: "min-h-screen", data: { controller: "datatable" }) do
          text_field_tag(
            :search,
            nil,
            type: :text,
            placeholder: "#{action_message(:search)}...",
            class: "w-full border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent",
            data: { action: "input->datatable#filter" }
          )

          div(class: "my-4", data: { datatable_target: "table" }) do
            div(class: "rounded-lg border-1 border-slate-300 shadow-sm overflow-hidden") do
              div(class: "bg-slate-300 grid grid-cols-6 py-1 gap-1 border-b border-slate-400 rounded-t-lg font-semibold text-black font-graduate") do
                div(class: "col-span-2 text-center") { model_attribute(UserBankAccount, :description) }
                div(class: "text-center") { model_attribute(UserBankAccount, :count) }
                div(class: "text-end") { model_attribute(UserBankAccount, :spent) }
                div(class: "text-end") { model_attribute(UserBankAccount, :balance) }
                div(class: "text-center") { I18n.t(:datatable_actions) }
              end

              if user_bank_accounts.present?
                user_bank_accounts.each do |record|
                  render Views::UserBankAccounts::UserBankAccount.new(user_bank_account: record, mobile: false)
                end
              else
                div(class: "border-b border-slate-200 py-2 my-2 text-lg bg-white") { I18n.t(:rows_not_found) }
              end
            end
          end
        end
      end
    end
  end

  def mobile_index
    div(class: "w-full") do
      div(class: "min-w-full") do
        turbo_frame_tag :user_bank_accounts do
          div(class: "min-h-screen", data: { controller: "datatable" }) do
            div(class: "p-3 mb-6 bg-white rounded-lg shadow-sm grid grid-cols-1 gap-2") do
              link_to(
                include_inactive? ? action_message(:show_inactive) : action_message(:hide_inactive),
                user_bank_accounts_path(include_inactive: include_inactive?),
                class: "p-1 rounded-sm border border-slate-700 bg-sky-500 hover:bg-blue-400 transition-colors text-white shadow-lg font-thin",
                data: { turbo_frame: "_top" }
              )

              text_field_tag(
                :search,
                nil,
                type: :text,
                placeholder: "#{action_message(:search)}...",
                class: "w-full border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent",
                data: { action: "input->datatable#filter" }
              )
            end

            div(class: "mb-8", data: { datatable_target: "table" }) do
              if user_bank_accounts.present?
                user_bank_accounts.each do |record|
                  render Views::UserBankAccounts::UserBankAccount.new(user_bank_account: record, mobile: true)
                end
              else
                div(class: "border-b border-slate-200 py-2 my-2 text-lg bg-white") { I18n.t(:rows_not_found) }
              end
            end
          end

          link_to(
            new_user_bank_account_path,
            style: "margin: 30px",
            class: "fixed bottom-0 right-0 bg-blue-600 text-white rounded-full shadow-lg flex items-center justify-center z-50 active:scale-95 transition-transform",
            data: { turbo_frame: "_top" }
          ) { cached_icon(:bigger_plus) }
        end
      end
    end
  end
end
