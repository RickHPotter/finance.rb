# frozen_string_literal: true

class Views::UserBankAccounts::Index < Views::Base
  include Phlex::Rails::Helpers::LinkTo

  include TranslateHelper
  include CacheHelper

  attr_reader :user_bank_accounts, :index_context, :mobile

  def initialize(user_bank_accounts:, index_context: {}, mobile: false)
    @user_bank_accounts = user_bank_accounts
    @index_context = index_context
    @mobile = mobile
  end

  def view_template
    turbo_frame_tag :center_container do
      div(class: resource_index_shell_class) do
        render_hero
        mobile ? mobile_index : desktop_index
      end
    end
  end

  private

  def render_hero
    div(class: resource_index_hero_class) do
      h1(class: resource_index_title_class) { action_model(:index, UserBankAccount, 2) }
      next if mobile

      link_to(
        action_model(:newa, UserBankAccount),
        new_user_bank_account_path,
        class: index_new_button_class,
        data: { turbo_frame: "_top" }
      )
    end
  end

  def desktop_index
    div(class: "min-w-full") do
      turbo_frame_tag :user_bank_accounts do
        div(class: "min-h-full", data: { controller: "datatable" }) do
          render Views::UserBankAccounts::IndexSearchForm.new(index_context:, mobile: false)

          div(class: "my-4", data: { datatable_target: "table" }) do
            div(class: resource_table_shell_class) do
              render Views::Shared::TableHeader.new(
                grid_class: "grid grid-cols-7",
                rows: [
                  [
                    { class: "col-span-2 flex justify-center", label: model_attribute(UserBankAccount, :description), align: :center },
                    { class: "flex justify-center", label: model_attribute(UserBankAccount, :status), align: :center },
                    { class: "flex justify-center", label: model_attribute(UserBankAccount, :count), align: :center },
                    { class: "flex items-end justify-end", label: model_attribute(UserBankAccount, :spent), align: :right },
                    { class: "flex items-end justify-end", label: model_attribute(UserBankAccount, :balance), align: :right },
                    { class: "flex justify-center", label: I18n.t(:datatable_actions) }
                  ]
                ]
              )

              if user_bank_accounts.present?
                user_bank_accounts.each do |record|
                  render Views::UserBankAccounts::UserBankAccount.new(user_bank_account: record, mobile: false)
                end
              else
                div(class: resource_empty_row_class) { I18n.t(:rows_not_found) }
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
          div(class: "min-h-full", data: { controller: "datatable" }) do
            div(class: resource_mobile_filter_shell_class) do
              render Views::UserBankAccounts::IndexSearchForm.new(index_context:, mobile: true)
            end

            div(class: "mb-8", data: { datatable_target: "table" }) do
              if user_bank_accounts.present?
                user_bank_accounts.each do |record|
                  render Views::UserBankAccounts::UserBankAccount.new(user_bank_account: record, mobile: true)
                end
              else
                div(class: resource_empty_row_class) { I18n.t(:rows_not_found) }
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
